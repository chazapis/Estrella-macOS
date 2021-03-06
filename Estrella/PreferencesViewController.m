//
// PreferencesViewController.m
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

#import "PreferencesViewController.h"

@implementation PreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.delegate fillInPreferencesViewController:self];
}

- (IBAction)applyPressed:(id)sender {
    if ([self.userCallsignTextField.stringValue isEqualToString:@""] ||
        [self.reflectorCallsignTextField.stringValue isEqualToString:@""] ||
        [self.reflectorModuleTextField.stringValue isEqualToString:@""] ||
        [self.reflectorHostTextField.stringValue isEqualToString:@""]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Empty configuration";
        alert.informativeText = @"All fields are required to establish a connection to the reflector.";
        [alert runModal];
    } else {
        [self.delegate applyChangesFromPreferencesViewController:self];
        [self dismissController:self];
    }
}

#pragma mark NSResponder

- (void)cancelOperation:(id)sender {
    [self dismissController:self];
}

- (void)complete:(id)sender {
    [self dismissController:self];
}

@end
