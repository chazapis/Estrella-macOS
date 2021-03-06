//
// ConnectionViewController.h
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

#import <Cocoa/Cocoa.h>
#import <CocoaDV/CocoaDV.h>

#import "PreferencesViewController.h"

@interface ConnectionViewController : NSViewController <DExtraClientDelegate, PreferencesViewControllerDelegate>

- (IBAction)showPreferences:(id)sender;
- (IBAction)pressPTT:(id)sender;

@property (nonatomic, weak) IBOutlet NSView *statusView;
@property (nonatomic, weak) IBOutlet NSTextField *repeaterTextField;
@property (nonatomic, weak) IBOutlet NSTextField *userTextField;
@property (nonatomic, weak) IBOutlet NSTextField *infoTextField;
@property (nonatomic, weak) IBOutlet NSButton *pttButton;

@end
