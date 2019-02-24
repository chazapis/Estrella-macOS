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

- (void)viewWillAppear {
    // XXX: Cycle through elements does not work for some reason...
//    [[[self view] window] setInitialFirstResponder:self.applyButton];
}

- (IBAction)applyPressed:(id)sender {
    [self.delegate applyChangesFromPreferencesViewController:self];
    [self dismissController:self];
}

#pragma mark NSResponder

- (void)cancelOperation:(id)sender {
    [self dismissController:self];
}

@end
