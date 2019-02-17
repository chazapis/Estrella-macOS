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

@interface DExtraClient ()

- (void)connect;

@property (nonatomic, strong) GCDAsyncUdpSocket *socket;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSString *callsign;

@end

@implementation DExtraClient

- (id)init {
    if ((self = [super init])) {
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

- (void)connectToHost:(NSString *)host port:(NSInteger)port usingCallsign:(NSString *)callsign {
    if ([self.host isEqual:host] &&
        self.port == port &&
        [self.callsign isEqual:callsign]) {
        return;
    }

    [self disconnect];

    self.host = host;
    self.port = port;
    self.callsign = callsign;
    [self connect];
}

- (void)connect {
}

- (void)disconnect {
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    // You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (msg)
    {
        NSLog(@"RECV: %@", msg);
    }
    else
    {
        NSString *host = nil;
        uint16_t port = 0;
        [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        
        NSLog(@"RECV: Unknown message from: %@:%hu", host, port);
    }
}

@end
