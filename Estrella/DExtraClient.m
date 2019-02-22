//
// DExtraClient.m
//
// Copyright (C) 2019 Antony Chazapis SV9OAN
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#import "DExtraClient.h"

#import "DExtraConnectPacket.h"
#import "DExtraConnectAckPacket.h"
#import "DExtraConnectNackPacket.h"
#import "DExtraDisconnectPacket.h"
#import "DExtraDisconnectAckPacket.h"
#import "DExtraKeepAlivePacket.h"
#import "DVHeaderPacket.h"
#import "DVFramePacket.h"

typedef NS_ENUM(NSInteger, DExtraClientStatus) {
    DExtraClientStatusIdle,             // Not connected
    DExtraClientStatusConnecting,       // In the process of connecting
    DExtraClientStatusConnected,        // Connected (normal operation)
    DExtraClientStatusFailed,           // Connection refused
    DExtraClientStatusDisconnecting,    // In the process of disconnecting
    DExtraClientStatusLost              // Connection lost and will try to reconnect
};

typedef NS_ENUM(NSInteger, DExtraPacketTag) {
    DExtraPacketTagConnect,
    DExtraPacketTagDisconnect,
    DExtraPacketTagKeepAlive
};

@interface DExtraClient ()

- (void)connect;

@property (nonatomic, strong) GCDAsyncUdpSocket *socket;
@property (atomic, assign) DExtraClientStatus status;
@property (atomic, strong) NSDate *lastHeard;

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSString *reflectorCallsign;
@property (nonatomic, strong) NSString *reflectorModule;
@property (nonatomic, strong) NSString *userCallsign;

@end

@implementation DExtraClient

- (id)init {
    if ((self = [super init])) {
        self.status = DExtraClientStatusIdle;
        // XXX: need a thread or timer to handle reconnects (start after socket is initialized)

        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        [self.socket setPreferIPv4];

        NSError *error = nil;
        
        if (![self.socket bindToPort:0 error:&error]) {
            NSLog(@"DExtraClient: Error binding socket: %@", error);
            return nil;
        }
        if (![self.socket beginReceiving:&error]) {
            NSLog(@"DExtraClient: Error receiving on socket: %@", error);
            return nil;
        }
    }
    
    return self;
}

- (void)connectToHost:(NSString *)host
                 port:(NSInteger)port
             callsign:(NSString *)reflectorCallsign
               module:(NSString *)reflectorModule
        usingCallsign:(NSString *)userCallsign {
    if ([self.host isEqual:host] &&
        self.port == port &&
        [self.reflectorCallsign isEqualToString:reflectorCallsign] &&
        [self.reflectorModule isEqualToString:reflectorModule] &&
        [self.userCallsign isEqualToString:userCallsign]) {
        return;
    }

    [self disconnect];

    self.host = host;
    self.port = port;
    self.reflectorCallsign = reflectorCallsign;
    self.reflectorModule = reflectorModule;
    self.userCallsign = userCallsign;
    [self connect];
}

- (void)connect {
    self.status = DExtraClientStatusConnecting;

    DExtraConnectPacket *connectPacket = [[DExtraConnectPacket alloc] initWithSrcCallsign:self.userCallsign
                                                                                srcModule:@""
                                                                               destModule:self.reflectorModule
                                                                                 revision:1];
    [self.socket sendData:[connectPacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagConnect];
    NSLog(@"DExtraClient: Sent packet with data: %@", [connectPacket toData]);

    // XXX: wait to get result
}

- (void)disconnect {
    if (self.status == DExtraClientStatusIdle)
        return;

    self.status = DExtraClientStatusConnecting;
    
    DExtraDisconnectPacket *disconnectPacket = [[DExtraDisconnectPacket alloc] initWithSrcCallsign:self.userCallsign srcModule:@""];
    [self.socket sendData:[disconnectPacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagDisconnect];
    NSLog(@"DExtraClient: Sent packet with data: %@", [disconnectPacket toData]);

    // XXX: wait to get result
}

#pragma mark GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"DExtraClient: Could not send data with tag: %ld error: %@", tag, [error localizedDescription]);
    switch (tag) {
        case DExtraPacketTagConnect:
            self.status = DExtraClientStatusLost;
            break;
        case DExtraPacketTagDisconnect:
        case DExtraPacketTagKeepAlive:
            break;
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    id packet;
    BOOL valid = YES;

    NSLog(@"DExtraClient: Received packet with data: %@", data);
    switch (self.status) {
        case DExtraClientStatusConnecting:
            if ((packet = [DExtraConnectAckPacket packetFromData:data]) != nil) {
                self.lastHeard = [NSDate date];
                self.status = DExtraClientStatusConnected;
            } else if ((packet = [DExtraConnectNackPacket packetFromData:data]) != nil) {
                self.status = DExtraClientStatusFailed;
            } else {
                valid = NO;
            }
            break;
        case DExtraClientStatusConnected:
            if ((packet = [DVHeaderPacket packetFromData:data]) != nil) {
                self.lastHeard = [NSDate date];
                ;
            } else if ((packet = [DVFramePacket packetFromData:data]) != nil) {
                self.lastHeard = [NSDate date];
                ;
            } else if ((packet = [DExtraKeepAlivePacket packetFromData:data]) != nil) {
                self.lastHeard = [NSDate date];
                DExtraKeepAlivePacket *keepAlivePacket = [[DExtraKeepAlivePacket alloc] initWithSrcCallsign:self.userCallsign];
                [self.socket sendData:[keepAlivePacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagKeepAlive];
                NSLog(@"DExtraClient: Sent packet with data: %@", [keepAlivePacket toData]);
            } else {
                valid = NO;
            }
            break;
        case DExtraClientStatusDisconnecting:
            if ((packet = [DExtraDisconnectAckPacket packetFromData:data]) != nil) {
                self.status = DExtraClientStatusIdle;
            } else {
                valid = NO;
            }
            break;
        case DExtraClientStatusIdle:
        case DExtraClientStatusFailed:
        case DExtraClientStatusLost:
            valid = NO;
            break;
    }

    if (!valid) {
        NSString *host = nil;
        uint16_t port = 0;
        [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        NSLog(@"DExtraClient: Unknown packet from host: %@ port: %hu data: %@", host, port, data);
    }
}

@end
