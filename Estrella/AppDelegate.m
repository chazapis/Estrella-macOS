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
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"] == nil) {
        NSDictionary *defaultPreferences = @{@"UserCallsign": @"",
                                             @"ReflectorCallsign": @"",
                                             @"ReflectorHost": @"",
                                             @"ReflectorModule": @"",
                                             @"ConnectAutomatically": @NO};
        [[NSUserDefaults standardUserDefaults] setObject:@[defaultPreferences] forKey:@"Connections"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // XXX: Close all connections...
}

- (NSDictionary *)preferencesForConnectionAtPosition:(NSInteger)position {
    NSArray *connectionsPreferences = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"];
    return connectionsPreferences[position];
}

- (void)savePreferences:(NSDictionary *)preferences forConnectionAtPosition:(NSInteger)position {
    NSMutableArray *connectionsPreferences = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"]];
    connectionsPreferences[position] = preferences;
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:connectionsPreferences] forKey:@"Connections"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
