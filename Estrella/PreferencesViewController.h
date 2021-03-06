//
// PreferencesViewController.h
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

@class PreferencesViewController;

@protocol PreferencesViewControllerDelegate <NSObject>

- (void)fillInPreferencesViewController:(PreferencesViewController *)preferencesViewController;
- (void)applyChangesFromPreferencesViewController:(PreferencesViewController *)preferencesViewController;

@end

@interface PreferencesViewController : NSViewController

- (IBAction)applyPressed:(id)sender;

@property (nonatomic, weak) id <PreferencesViewControllerDelegate> delegate;

@property (nonatomic, weak) IBOutlet NSTextField *userCallsignTextField;
@property (nonatomic, weak) IBOutlet NSTextField *reflectorCallsignTextField;
@property (nonatomic, weak) IBOutlet NSTextField *reflectorModuleTextField;
@property (nonatomic, weak) IBOutlet NSTextField *reflectorHostTextField;
@property (nonatomic, weak) IBOutlet NSButton *connectAutomaticallyButton;

@end
