//
// ConnectionViewController.m
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

#import "ConnectionViewController.h"
#import "AppDelegate.h"

@interface ConnectionViewController ()

- (void)connect;
- (void)disconnect;

- (void)loadConnectionPreferences:(NSDictionary *)connectionPreferences;

- (BOOL)isValidCallsign:(NSString *)callsign;
- (BOOL)isValidModule:(NSString *)module;

@property (nonatomic, strong) DExtraClient *dextraClient;

@property (nonatomic, strong) NSString *userCallsign;
@property (nonatomic, strong) NSString *reflectorCallsign;
@property (nonatomic, strong) NSString *reflectorModule;
@property (nonatomic, strong) NSString *reflectorHost;
@property (nonatomic, assign) BOOL connectAutomatically;

@end

@implementation ConnectionViewController

- (void)dealloc {
    if (self.dextraClient)
        [self.dextraClient disconnect];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.dextraClient = nil;

    self.line1TextField.stringValue = @"";
    self.line2TextField.stringValue = @"";
    self.line3TextField.stringValue = @"";
    self.line4TextField.stringValue = @"";
    self.statusButton.enabled = NO;
    self.statusButton.title = @"RX";
    
    // Get preferences
    NSDictionary *defaultPreferences = @{@"UserCallsign": @"",
                                         @"ReflectorCallsign": @"",
                                         @"ReflectorModule": @"",
                                         @"ReflectorHost": @"",
                                         @"ConnectAutomatically": @NO};
    NSArray *connectionsPreferences = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"];
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"] == nil) {
        [self loadConnectionPreferences:defaultPreferences];
        [[NSUserDefaults standardUserDefaults] setObject:@[defaultPreferences] forKey:@"Connections"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [self loadConnectionPreferences:connectionsPreferences[0]]; // Only one connection for now
    }
    
    NSLog(@"ConnectionViewController: Loaded with userCallsign: %@ reflectorCallsign: %@ reflectorModule: %@ reflectorHost: %@ connectAutomatically: %hhu", self.userCallsign, self.reflectorCallsign, self.reflectorModule, self.reflectorHost, self.connectAutomatically);

    if (![self isValidCallsign:self.userCallsign] ||
        ![self isValidCallsign:self.reflectorCallsign] ||
        ![self isValidModule:self.reflectorModule]) {
        // Reset to default, as preferences are completely off
        [self loadConnectionPreferences:defaultPreferences];
        [[NSUserDefaults standardUserDefaults] setObject:@[defaultPreferences] forKey:@"Connections"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)viewDidAppear {
    if (![self.userCallsign isEqualToString:@""] &&
        ![self.reflectorCallsign isEqualToString:@""] &&
        ![self.reflectorModule isEqualToString:@""] &&
        ![self.reflectorHost isEqualToString:@""] &&
        self.connectAutomatically) {
        [self connect];
    } else {
        [self showPreferences:self];
    }
}

- (void)connect {
    NSLog(@"ConnectionViewController: Connect to reflector");
//    self.dextraClient = [[DExtraClient alloc] initWithHost:self.reflectorHost
//                                                      port:30201
//                                                  callsign:self.reflectorCallsign
//                                                    module:self.reflectorModule
//                                             usingCallsign:self.userCallsign];
//    [self.dextraClient connect];
}

- (void)disconnect {
    NSLog(@"ConnectionViewController: Disconnect from reflector");
//    [self.dextraClient disconnect];
}

- (void)loadConnectionPreferences:(NSDictionary *)connectionPreferences {
    self.userCallsign = connectionPreferences[@"UserCallsign"];
    self.reflectorCallsign = connectionPreferences[@"ReflectorCallsign"];
    self.reflectorModule = connectionPreferences[@"ReflectorModule"];
    self.reflectorHost = connectionPreferences[@"ReflectorHost"];
    self.connectAutomatically = [connectionPreferences[@"ConnectAutomatically"] boolValue];
}

- (BOOL)isValidCallsign:(NSString *)callsign {
    if ([callsign length] == 0)
        return YES;
    if ([callsign length] > 8)
        return NO;
    unichar c;
    for (int i = 0; i < [callsign length]; i++) {
        c = [callsign characterAtIndex:i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z')))
            return NO;
    }
    return YES;
}

- (BOOL)isValidModule:(NSString *)module {
    if ([module length] == 0)
        return YES;
    if ([module length] > 1)
        return NO;
    unichar c = [module characterAtIndex:0];
    if (!(c >= 'A' && c <= 'Z'))
        return NO;
    return YES;
}

- (IBAction)showPreferences:(id)sender {
    [self performSegueWithIdentifier:@"ShowPreferencesSegue" sender:self];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if (![segue.identifier isEqualToString:@"ShowPreferencesSegue"])
        return;
    
    PreferencesViewController *preferencesViewController = (PreferencesViewController *)segue.destinationController;
    preferencesViewController.delegate = self;
}

# pragma mark DExtraClientDelegate

- (void)dextraClient:(DExtraClient *)client didChangeStatusTo:(DExtraClientStatus)status {
    NSLog(@"ConnectionViewController: Connection status changed to: %ld", status);
    switch (status) {
        case DExtraClientStatusIdle:
            // Disconnected
            [self connect];
            break;
        case DExtraClientStatusFailed:
        case DExtraClientStatusLost:
            // Wait a while before trying to reconnect
            [self performSelector:@selector(connect) withObject:nil afterDelay:3];
            break;
        case DExtraClientStatusConnecting:
        case DExtraClientStatusConnected:
        case DExtraClientStatusDisconnecting:
            break;
    }
}

# pragma mark PreferencesViewControllerDelegate

- (void)fillInPreferencesViewController:(PreferencesViewController *)preferencesViewController {
    preferencesViewController.userCallsignTextField.stringValue = self.userCallsign;
    preferencesViewController.reflectorCallsignTextField.stringValue = self.reflectorCallsign;
    preferencesViewController.reflectorModuleTextField.stringValue = self.reflectorModule;
    preferencesViewController.reflectorHostTextField.stringValue = self.reflectorHost;
    preferencesViewController.connectAutomaticallyButton.state = (self.connectAutomatically ? NSControlStateValueOn : NSControlStateValueOff);
}

- (void)applyChangesFromPreferencesViewController:(PreferencesViewController *)preferencesViewController {
    NSLog(@"ConnectionViewController: Connection preferences changed");
    
    NSString *userCallsign = preferencesViewController.userCallsignTextField.stringValue;
    NSString *reflectorCallsign = preferencesViewController.reflectorCallsignTextField.stringValue;
    NSString *reflectorModule = preferencesViewController.reflectorModuleTextField.stringValue;
    NSString *reflectorHost = preferencesViewController.reflectorHostTextField.stringValue;
    BOOL connectAutomatically = preferencesViewController.connectAutomaticallyButton.state;

    BOOL shouldReconnect = NO;
    BOOL shouldSave = NO;

    if (![self.userCallsign isEqualToString:userCallsign] ||
        ![self.reflectorCallsign isEqualToString:reflectorCallsign] ||
        ![self.reflectorModule isEqualToString:reflectorModule] ||
        ![self.reflectorHost isEqualToString:reflectorHost])
        shouldReconnect = YES;
    if (shouldReconnect || self.connectAutomatically != connectAutomatically)
        shouldSave = YES;

    if (shouldSave) {
        NSDictionary *connectionPreferences = @{@"UserCallsign": userCallsign,
                                                @"ReflectorCallsign": reflectorCallsign,
                                                @"ReflectorModule": reflectorModule,
                                                @"ReflectorHost": reflectorHost,
                                                @"ConnectAutomatically": [NSNumber numberWithBool:connectAutomatically]};
        [self loadConnectionPreferences:connectionPreferences];
        NSMutableArray *connectionsPreferences = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"]];
        connectionsPreferences[0] = connectionPreferences; // Only one connection for now
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:connectionsPreferences] forKey:@"Connections"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (shouldReconnect) {
        if (self.dextraClient) {
            [self disconnect];
        } else {
            [self connect];
        }
    }
}

@end
