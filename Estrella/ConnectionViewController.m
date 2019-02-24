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

@property (nonatomic, strong) NSDictionary *connectionPreferences;
@property (nonatomic, strong) DExtraClient *dextraClient;

@end

@implementation ConnectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Get preferences
    NSArray *connectionsPreferences = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"];
    self.connectionPreferences = connectionsPreferences[0]; // Only one connection for now
    NSLog(@"ConnectionViewController: Loaded with userCallsign: %@ reflectorCallsign: %@ reflectorModule: %@ reflectorHost: %@ connectAutomatically: %@", self.connectionPreferences[@"UserCallsign"], self.connectionPreferences[@"ReflectorCallsign"], self.connectionPreferences[@"ReflectorModule"],  self.connectionPreferences[@"ReflectorHost"], self.connectionPreferences[@"ConnectAutomatically"]);

    // XXX: Check for callsign and address validity...
    // XXX: Split reflector callsign and module...
    
}

- (void)viewDidAppear {
    if ([self.connectionPreferences[@"ConnectAutomatically"] boolValue]) {
        [self connect];
    } else {
        [self showPreferences:self];
    }
}

- (void)connect {
    NSLog(@"ConnectionViewController: Connect to reflector");
//    self.dextraClient = [[DExtraClient alloc] initWithHost:self.connectionPreferences[@"ReflectorHost"]
//                                                      port:30201
//                                                  callsign:self.connectionPreferences[@"ReflectorCallsign"]
//                                                    module:self.connectionPreferences[@"ReflectorModule"]
//                                             usingCallsign:self.connectionPreferences[@"UserCallsign"]];
//    [self.dextraClient connect];
}

- (void)disconnect {
    NSLog(@"ConnectionViewController: Disconnect from reflector");
//    [self.dextraClient disconnect];
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
}

# pragma mark PreferencesViewControllerDelegate

- (void)fillInPreferencesViewController:(PreferencesViewController *)preferencesViewController {
    preferencesViewController.userCallsignTextField.stringValue = self.connectionPreferences[@"UserCallsign"];
    preferencesViewController.reflectorCallsignTextField.stringValue = self.connectionPreferences[@"ReflectorCallsign"];
    preferencesViewController.reflectorModuleTextField.stringValue = self.connectionPreferences[@"ReflectorModule"];
    preferencesViewController.reflectorHostTextField.stringValue = self.connectionPreferences[@"ReflectorHost"];
    preferencesViewController.connectAutomaticallyButton.state = ([self.connectionPreferences[@"ConnectAutomatically"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff);
}

- (void)applyChangesFromPreferencesViewController:(PreferencesViewController *)preferencesViewController {
    NSLog(@"ConnectionViewController: Connection preferences changed");

    NSString *userCallsign = preferencesViewController.userCallsignTextField.stringValue;
    NSString *reflectorCallsign = preferencesViewController.reflectorCallsignTextField.stringValue;
    NSString *reflectorModule = preferencesViewController.reflectorModuleTextField.stringValue;
    NSString *reflectorHost = preferencesViewController.reflectorHostTextField.stringValue;
    BOOL connectAutomatically = preferencesViewController.connectAutomaticallyButton.state;
    
    if (![self.connectionPreferences[@"UserCallsign"] isEqualToString:userCallsign] ||
        ![self.connectionPreferences[@"ReflectorCallsign"] isEqualToString:reflectorCallsign] ||
        ![self.connectionPreferences[@"ReflectorModule"] isEqualToString:reflectorModule] ||
        ![self.connectionPreferences[@"ReflectorHost"] isEqualToString:reflectorHost] ||
        [self.connectionPreferences[@"ConnectAutomatically"] boolValue] != connectAutomatically) {
        self.connectionPreferences = @{@"UserCallsign": userCallsign,
                                       @"ReflectorCallsign": reflectorCallsign,
                                       @"ReflectorHost": reflectorHost,
                                       @"ReflectorModule": reflectorModule,
                                       @"ConnectAutomatically": [NSNumber numberWithBool:connectAutomatically]};
        NSMutableArray *connectionsPreferences = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Connections"]];
        connectionsPreferences[0] = self.connectionPreferences; // Only one connection for now
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:connectionsPreferences] forKey:@"Connections"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
