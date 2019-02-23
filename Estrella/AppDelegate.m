//
// AppDelegate.m
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

#import "AppDelegate.h"

#import "DExtraClient.h"
#import "DSTARHeader.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // Initialize the server connection.
    self.dextraClient = [[DExtraClient alloc] initWithHost:@"157.230.110.14"
                                                      port:30201
                                                  callsign:@"ORF939"
                                                    module:@"B"
                                             usingCallsign:@"SV9OAP"];
    [self.dextraClient connect];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    
    // Disconnect from the server.
    [self.dextraClient disconnect];
}

@end
