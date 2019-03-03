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

#import <AVFoundation/AVFoundation.h>
#import <CocoaCodec2/codec2.h>

@interface ConnectionViewController () {
    struct CODEC2 *codec2State;
};

- (void)connect;
- (void)disconnect;

- (void)loadConnectionPreferences:(NSDictionary *)connectionPreferences;

- (BOOL)isValidCallsign:(NSString *)callsign;
- (BOOL)isValidModule:(NSString *)module;

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *audioPlayerNode;
@property (nonatomic, strong) AVAudioFormat *audioPlayerFormat;

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
    codec2_destroy(codec2State);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Codec context
    codec2State = codec2_create(CODEC2_MODE_3200);

    // Initialize audio
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.audioPlayerNode = [[AVAudioPlayerNode alloc] init];
    self.audioPlayerFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:8000 channels:2 interleaved:NO];

    NSError *error;
    
    [self.audioEngine attachNode:self.audioPlayerNode];
    [self.audioEngine connect:self.audioPlayerNode to:self.audioEngine.mainMixerNode format:self.audioPlayerFormat];
    [self.audioEngine prepare];
    if (![self.audioEngine startAndReturnError:&error])
        NSLog(@"ConnectionViewController: Could not start audio engine: %@", error.description);
    // XXX: Start and stop for every transmission...
    [self.audioPlayerNode play];

    // Our connection to the server
    self.dextraClient = nil;
    
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

- (void)viewWillAppear {
    self.line1TextField.stringValue = @"";
    self.line2TextField.stringValue = @"";
    self.line3TextField.stringValue = @"";
    self.line4TextField.stringValue = @"";
    self.statusButton.enabled = NO;
    self.statusButton.title = @"RX";
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
    self.dextraClient = [[DExtraClient alloc] initWithHost:self.reflectorHost
                                                      port:30201
                                                  callsign:self.reflectorCallsign
                                                    module:self.reflectorModule
                                             usingCallsign:self.userCallsign];
    self.dextraClient.delegate = self;
    [self.dextraClient connect];
}

- (void)disconnect {
    NSLog(@"ConnectionViewController: Disconnect from reflector");
    [self.dextraClient disconnect];
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
    NSLog(@"ConnectionViewController: Connection status changed to: %@", NSStringFromDExtraClientStatus(status));
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

- (void)dextraClient:(DExtraClient *)client didReceiveDVHeaderPacket:(DVHeaderPacket *)dvHeader {
}

- (void)dextraClient:(DExtraClient *)client didReceiveDVFramePacket:(DVFramePacket *)dvFrame {
    AVAudioPCMBuffer *audioPCMBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.audioPlayerFormat frameCapacity:160];

    // Providing a PCM buffer with a single channel of 16 bit integers fails,
    // so the voice data is converted to dual channel floating point
    short *voice = (short *)malloc(sizeof(short) * 160);
    float *fvoice = (float *)malloc(sizeof(float) * 160);
    codec2_decode(codec2State, voice, dvFrame.dstarFrame.codec.bytes);
    for (int i = 0; i < 160; i++)
        fvoice[i] = ((float)voice[i]) / 32768.0;
    audioPCMBuffer.frameLength = 160;
    memcpy(audioPCMBuffer.floatChannelData[0], fvoice, sizeof(float) * 160);
    memcpy(audioPCMBuffer.floatChannelData[1], fvoice, sizeof(float) * 160);
    free(fvoice);
    free(voice);

    [self.audioPlayerNode scheduleBuffer:audioPCMBuffer completionHandler:nil];
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
    NSLog(@"ConnectionViewController: shouldReconnect: %hhu shouldSave: %hhu", shouldReconnect, shouldSave);

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
    if (!self.dextraClient) {
        [self connect];
    } else if (shouldReconnect) {
        [self disconnect];
    }
}

@end
