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

typedef NS_ENUM(NSInteger, DExtraPacketTag) {
    DExtraPacketTagConnect,
    DExtraPacketTagDisconnect,
    DExtraPacketTagKeepAlive
};

@interface DExtraClient ()

- (void)connect;

@property (nonatomic, assign) DExtraClientStatus status;
@property (nonatomic, strong) GCDAsyncUdpSocket *socket;
@property (atomic, strong) NSDate *lastHeard;

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSString *reflectorCallsign;
@property (nonatomic, strong) NSString *reflectorModule;
@property (nonatomic, strong) NSString *userCallsign;

@end

@implementation DExtraClient

- (id)initWithHost:(NSString *)host
              port:(NSInteger)port
          callsign:(NSString *)reflectorCallsign
            module:(NSString *)reflectorModule
     usingCallsign:(NSString *)userCallsign {
    if ((self = [super init])) {
        _delegate = nil;
        _status = DExtraClientStatusIdle;

        self.host = host;
        self.port = port;
        self.reflectorCallsign = reflectorCallsign;
        self.reflectorModule = reflectorModule;
        self.userCallsign = userCallsign;
    }
    
    return self;
}

// Custom property, so the same protection mechanism can be used by other internal functions
@synthesize status = _status;

- (void)setStatus:(DExtraClientStatus)status {
    @synchronized (self) {
        _status = status;
    }
    if (_delegate != nil)
        [_delegate dextraClient:self didChangeStatusTo:status];
}

- (DExtraClientStatus)status {
    @synchronized (self) {
        return _status;
    }
}

- (void)connect {
    @synchronized (self) {
        if (_status != DExtraClientStatusIdle)
            return;
        
        _status = DExtraClientStatusConnecting;
    }

    self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.socket setPreferIPv4];
    
    NSError *error = nil;
    
    if (![self.socket bindToPort:0 error:&error] || ![self.socket beginReceiving:&error]) {
        NSLog(@"DExtraClient: Error binding or reveiving on socket: %@", error);
        @synchronized (self) {
            if (_status == DExtraClientStatusConnecting)
                _status = DExtraClientStatusFailed;
        }
        return;
    }

    // XXX: Need a thread or timer to handle reconnects (start after socket is initialized)...

    DExtraConnectPacket *connectPacket = [[DExtraConnectPacket alloc] initWithSrcCallsign:self.userCallsign
                                                                                srcModule:@""
                                                                               destModule:self.reflectorModule
                                                                                 revision:1];
    [self.socket sendData:[connectPacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagConnect];
    NSLog(@"DExtraClient: Sent packet with data: %@", [connectPacket toData]);
}

- (void)disconnect {
    @synchronized (self) {
        if (_status == DExtraClientStatusIdle || _status == DExtraClientStatusDisconnecting)
            return;
        
        _status = DExtraClientStatusDisconnecting;
    }
    
    DExtraDisconnectPacket *disconnectPacket = [[DExtraDisconnectPacket alloc] initWithSrcCallsign:self.userCallsign srcModule:@""];
    [self.socket sendData:[disconnectPacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagDisconnect];
    NSLog(@"DExtraClient: Sent packet with data: %@", [disconnectPacket toData]);
}

#pragma mark GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"DExtraClient: Could not send data with tag: %ld error: %@", tag, [error localizedDescription]);
    if (tag == DExtraPacketTagConnect) {
        @synchronized (self) {
            if (_status == DExtraClientStatusConnecting)
                _status = DExtraClientStatusLost;
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    id packet;

    if ((packet = [DVFramePacket packetFromData:data]) == nil &&
        (packet = [DVHeaderPacket packetFromData:data]) == nil &&
        (packet = [DExtraKeepAlivePacket packetFromData:data]) == nil &&
        (packet = [DExtraConnectAckPacket packetFromData:data]) == nil &&
        (packet = [DExtraConnectNackPacket packetFromData:data]) == nil &&
        (packet = [DExtraDisconnectPacket packetFromData:data]) == nil &&
        (packet = [DExtraDisconnectAckPacket packetFromData:data]) == nil) {
        NSLog(@"DExtraClient: Unknown packet with data: %@", data);
        return;
    }
    
    NSLog(@"DExtraClient: Received packet: %@", packet);
    self.lastHeard = [NSDate date];
    
    // Packets that don't change state
    if ([packet isKindOfClass:[DVFramePacket class]] || [packet isKindOfClass:[DVHeaderPacket class]]) {
        return;
    }
    if ([packet isKindOfClass:[DExtraConnectAckPacket class]]) {
        DExtraKeepAlivePacket *keepAlivePacket = [[DExtraKeepAlivePacket alloc] initWithSrcCallsign:self.userCallsign];
        [self.socket sendData:[keepAlivePacket toData] toHost:self.host port:self.port withTimeout:3 tag:DExtraPacketTagKeepAlive];
        NSLog(@"DExtraClient: Exchanged keep alive packets");
        return;
    }

    @synchronized (self) {
        if ([packet isKindOfClass:[DExtraConnectAckPacket class]]) {
            if (_status == DExtraClientStatusConnecting)
                _status = DExtraClientStatusConnected;
        } else if ([packet isKindOfClass:[DExtraConnectNackPacket class]]) {
            if (_status == DExtraClientStatusConnecting)
                _status = DExtraClientStatusFailed;
        } else if ([packet isKindOfClass:[DExtraDisconnectPacket class]]) {
            _status = DExtraClientStatusIdle;
        } else if ([packet isKindOfClass:[DExtraDisconnectAckPacket class]]) {
            _status = DExtraClientStatusIdle;
        }
    }
}

@end
