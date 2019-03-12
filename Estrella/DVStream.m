//
// DVStream.m
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

#import "DVStream.h"

#include <stdlib.h>

#import "DVHeaderPacket.h"
#import "DVFramePacket.h"

@interface DVStream ()

@property (nonatomic, strong) NSMutableArray *packetArray;
@property (nonatomic, assign) unsigned char nextPacketId;

@end

@implementation DVStream

- (id)initWithDSTARHeader:(DSTARHeader *)dstarHeader {
    if (self = [super init]) {
        _streamId = arc4random_uniform(65536);
        
        self.packetArray = [[NSMutableArray alloc] initWithCapacity:1500]; // About 30 seconds of audio
        DVHeaderPacket *dvHeaderPacket = [[DVHeaderPacket alloc] initWithBand1:0
                                                                         band2:0
                                                                         band3:0
                                                                      streamId:_streamId
                                                                   dstarHeader:dstarHeader];
        [self.packetArray addObject:dvHeaderPacket];
        
        _nextPacketId = 0;
    }
    return self;

}

- (void)appendDSTARFrame:(DSTARFrame *)dstarFrame {
    DVFramePacket *dvFramePacket = [[DVFramePacket alloc] initWithBand1:0
                                                                  band2:0
                                                                  band3:0
                                                               streamId:self.streamId
                                                               packetId:self.nextPacketId
                                                             dstarFrame:dstarFrame];

    self.nextPacketId = (self.nextPacketId + 1) % 21;
    [self.packetArray addObject:dvFramePacket];
}

- (void)markLast {
    id packet = [self.packetArray lastObject];
    
    if ([packet isKindOfClass:[DVFramePacket class]]) {
        ((DVFramePacket *)packet).packetId |= 0x40;
    }
}

@end
