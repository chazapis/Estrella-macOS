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

#include <unistd.h>

typedef NS_ENUM(NSInteger, RadioStatus) {
    RadioStatusIdle,
    RadioStatusReceiving,
    RadioStatusTransmitting
};

@interface ConnectionViewController ()

- (void)connect;
- (void)disconnect;

- (void)loadConnectionPreferences:(NSDictionary *)connectionPreferences;

- (BOOL)isValidCallsign:(NSString *)callsign;
- (BOOL)isValidModule:(NSString *)module;

- (void)updateDisplay;

- (void)startTransmitting;
- (void)stopTransmitting;

- (void)checkStatus:(NSTimer *)timer;

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *audioPlayerNode;
@property (nonatomic, strong) AVAudioFormat *audioPlayerFormat;
@property (nonatomic, strong) AVAudioInputNode *audioInputNode;
@property (nonatomic, strong) AVAudioFormat *audioInputFormat;

@property (nonatomic, strong) DVCodec *dvCodec;
@property (nonatomic, strong) dispatch_queue_t transmitQueue;

@property (nonatomic, strong) DExtraClient *dextraClient;
@property (atomic, strong) NSDate *statusCheckpoint;
@property (nonatomic, strong) NSTimer *statusTimer;

@property (nonatomic, assign) BOOL firstRun;
@property (nonatomic, assign) BOOL firstConnect;
@property (nonatomic, strong) NSString *userCallsign;
@property (nonatomic, strong) NSString *reflectorCallsign;
@property (nonatomic, strong) NSString *reflectorModule;
@property (nonatomic, strong) NSString *reflectorHost;
@property (nonatomic, assign) BOOL connectAutomatically;

@property (nonatomic, assign) BOOL microphoneAvailable;
@property (nonatomic, assign) DExtraClientStatus clientStatus;
@property (nonatomic, assign) RadioStatus radioStatus;
@property (nonatomic, strong) DVHeaderPacket *receiveHeader;
@property (nonatomic, strong) DVStream *transmitStream;

@end

@implementation ConnectionViewController

- (void)dealloc {
    if (self.dextraClient)
        [self.dextraClient disconnect];
    if (self.statusTimer)
        [self.statusTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize audio
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.audioPlayerNode = [[AVAudioPlayerNode alloc] init];
    self.audioPlayerFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:8000 channels:2 interleaved:NO];
    self.audioInputNode = [self.audioEngine inputNode];
    self.audioInputFormat = [self.audioInputNode outputFormatForBus:0];
    
    NSError *error;
    
    [self.audioEngine attachNode:self.audioPlayerNode];
    [self.audioEngine connect:self.audioPlayerNode to:self.audioEngine.mainMixerNode format:self.audioPlayerFormat];
    [self.audioEngine prepare];
    if (![self.audioEngine startAndReturnError:&error])
        NSLog(@"ConnectionViewController: Could not start audio engine: %@", error.description);
    // XXX: Start and stop for every transmission...
    [self.audioPlayerNode play];

    // Codec and transmit processing queue
    self.dvCodec = [[DVCodec alloc] initWithPlayerFormat:self.audioPlayerFormat recorderFormat:self.audioInputFormat];
    self.transmitQueue = dispatch_queue_create("com.koomasi.Estrella.tx", NULL);
    dispatch_set_target_queue(self.transmitQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    // Our connection to the server
    self.dextraClient = nil;
    
    // Check if we are stuck in RX or TX
    self.statusCheckpoint = nil;
    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkStatus:) userInfo:nil repeats:YES];

    // Get preferences
    self.firstRun = YES;
    self.firstConnect = YES;
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
    
    // Radio state
    _microphoneAvailable = NO;
    _clientStatus = DExtraClientStatusIdle;
    _radioStatus = RadioStatusIdle; // Do not trigger a display update
    _receiveHeader = nil;
    _transmitStream = nil;
    
    // Start with disabled PTT
    self.pttButton.enabled = NO;
}

- (void)viewWillAppear {
    [self updateDisplay];
}

- (void)viewDidAppear {
    if (self.clientStatus == DExtraClientStatusIdle && self.firstRun) {
        self.firstRun = NO; // Do this only once.
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
    if ([callsign length] > 7) // The callsign without the module
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

- (void)updateDisplay {
    // The display structure is:
    // • Line 1: Show the frequency on the left ("NET" in our case), TX/RX status on the right
    // • Line 2: Show from and to callsigns
    // • Line 3: Show repeater and gateway callsigns
    // • Line 4: Show user data on RX, connectivity status, or other information

    if (self.radioStatus != RadioStatusIdle) {
        NSString *status = [NSString stringWithFormat:@"NET               %@", (self.radioStatus == RadioStatusTransmitting ? @"TX" : @"RX")];
        NSMutableAttributedString *attributedStatus = [[NSMutableAttributedString alloc] initWithString:status];
        [attributedStatus addAttribute:NSBackgroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(18, 2)];
        [attributedStatus addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(18, 2)];
        self.statusTextField.attributedStringValue = attributedStatus;
    } else {
        self.statusTextField.stringValue = @"NET";
    }

    if (self.clientStatus == DExtraClientStatusConnected) {
        if ((self.radioStatus == RadioStatusReceiving) && self.receiveHeader) {
            DSTARHeader *dstarHeader = self.receiveHeader.dstarHeader;
            NSString *paddedMyCallsign = [dstarHeader.myCallsign stringByPaddingToLength:8 withString:@" " startingAtIndex:0];
            self.userTextField.stringValue = [NSString stringWithFormat:@"%@ -> %@", paddedMyCallsign, dstarHeader.urCallsign];

            NSString *paddedRepeater1Callsign = [dstarHeader.repeater1Callsign stringByPaddingToLength:8 withString:@" " startingAtIndex:0];
            self.repeaterTextField.stringValue = [NSString stringWithFormat:@"%@ -> %@", paddedRepeater1Callsign, dstarHeader.repeater2Callsign];
        } else {
            NSString *paddedUserCallsign = [self.userCallsign stringByPaddingToLength:8 withString:@" " startingAtIndex:0];
            self.userTextField.stringValue = [NSString stringWithFormat:@"%@ -> CQCQCQ", paddedUserCallsign];

            NSString *paddedReflectorCallsign = [self.reflectorCallsign stringByPaddingToLength:7 withString:@" " startingAtIndex:0];
            self.repeaterTextField.stringValue = [NSString stringWithFormat:@"%@%@ -> %@G", paddedReflectorCallsign, self.reflectorModule, paddedReflectorCallsign];
        }
    } else {
        self.userTextField.stringValue = @"";
        self.repeaterTextField.stringValue = @"";
    }
    
    self.infoTextField.stringValue = NSStringFromDExtraClientStatus(self.clientStatus);
}

- (void)startTransmitting {
    self.statusCheckpoint = [NSDate date];
    self.radioStatus = RadioStatusTransmitting;
    
    NSString *paddedReflectorCallsign = [self.reflectorCallsign stringByPaddingToLength:7 withString:@" " startingAtIndex:0];
    DSTARHeader *dstarHeader = [[DSTARHeader alloc] initWithFlag1:0
                                                            flag2:0
                                                            flag3:1 // Codec 2, mode 3200 without FEC
                                                repeater1Callsign:[NSString stringWithFormat:@"%@%@", paddedReflectorCallsign, self.reflectorModule]
                                                repeater2Callsign:[NSString stringWithFormat:@"%@G", paddedReflectorCallsign]
                                                       urCallsign:@"CQCQCQ"
                                                       myCallsign:self.userCallsign
                                                         mySuffix:@""];
    self.transmitStream = [[DVStream alloc] initWithDSTARHeader:dstarHeader];
    
    // Get 200 ms worth of samples, which will be converted into 10 frames
    [self.audioInputNode installTapOnBus:0 bufferSize:(self.audioInputFormat.sampleRate * 0.2) format:self.audioInputFormat block:^(AVAudioPCMBuffer *inputBuffer, AVAudioTime *when) {
        // NSLog(@"ConnectionViewController: Got %d samples in the input buffer with format %@", inputBuffer.frameLength, inputBuffer.format);
        
        dispatch_async(self.transmitQueue, ^(void){
            [self.dvCodec encodeBuffer:inputBuffer intoStream:self.transmitStream];
        });
    }];
    
    [NSThread detachNewThreadWithBlock:^(void) {
        @autoreleasepool {
            // Keep these in case they change
            DExtraClient *dextraClient = self.dextraClient;
            DVStream *transmitStream = self.transmitStream;
            
            // Wait for the first samples to arrive
            while (transmitStream.dvPacketCount < 5)
                usleep(20000);
            for (int i = 0; i < transmitStream.dvPacketCount; i++) {
                [dextraClient sendDVPacket:[transmitStream dvPacketAtIndex:i]];
                usleep(20000);
            }
        }
    }];
}

- (void)stopTransmitting {
    [self.audioInputNode removeTapOnBus:0];
    [self.transmitStream markLast]; // We should have some packets in the buffer for this to work
    
    self.radioStatus = RadioStatusIdle;
}

- (void)checkStatus:(NSTimer *)timer {
    if (self.radioStatus == RadioStatusIdle || !self.statusCheckpoint)
        return;
    NSTimeInterval statusCheckpointInterval = [[NSDate date] timeIntervalSinceDate:self.statusCheckpoint];

    if ((self.radioStatus == RadioStatusTransmitting && statusCheckpointInterval > 120) ||
        (self.radioStatus == RadioStatusReceiving && statusCheckpointInterval > 1)) {
        self.radioStatus = RadioStatusIdle;
        return;
    }
}

- (void)setRadioStatus:(RadioStatus)radioStatus {
    // Enable and disable the PTT button in one place
    @synchronized (self) {
        _radioStatus = radioStatus;
        switch (_radioStatus) {
            case RadioStatusIdle:
                // XXX: If transmitting, depress button and remove audio tap...
                self.pttButton.enabled = ((self.clientStatus == DExtraClientStatusConnected) && self.microphoneAvailable);
                break;
            case RadioStatusReceiving:
                self.pttButton.enabled = NO;
                break;
            case RadioStatusTransmitting:
                break;
        }
    }
    
    [self updateDisplay];
}

- (IBAction)showPreferences:(id)sender {
    [self performSegueWithIdentifier:@"ShowPreferencesSegue" sender:self];
}

- (IBAction)pressPTT:(id)sender {
    if ([(NSButton *)sender state] == NSControlStateValueOn) {
        [self startTransmitting];
    } else {
        [self stopTransmitting];
    }
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
        {
            if (self.firstConnect) {
                self.firstConnect = NO;
                NSAlert *alert = [[NSAlert alloc] init];
                alert.alertStyle = NSAlertStyleCritical;
                alert.messageText = @"Connection failed";
                alert.informativeText = @"A connection to the reflector could not be established. Will retry, but please check the preferences and make sure network connectivity is available.";
                [alert runModal];
            }
        }
        case DExtraClientStatusLost:
            // Wait a while before trying to reconnect
            NSLog(@"ConnectionViewController: Reconnecting in 3 seconds");
            [self performSelector:@selector(connect) withObject:nil afterDelay:3];
            break;
        case DExtraClientStatusConnected:
            self.firstConnect = NO;
        case DExtraClientStatusConnecting:
        case DExtraClientStatusDisconnecting:
            break;
    }
    
    self.microphoneAvailable = NO;
    if (status == DExtraClientStatusConnected) {
        if (@available(macOS 10.14, *)) {
            switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
                case AVAuthorizationStatusAuthorized:
                    self.microphoneAvailable = YES;
                    break;
                case AVAuthorizationStatusNotDetermined:
                {
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                        if (granted) {
                            self.microphoneAvailable = YES;
                            [self updateDisplay];
                        }
                    }];
                    break;
                }
                case AVAuthorizationStatusDenied:
                {
                    NSAlert *alert = [[NSAlert alloc] init];
                    alert.alertStyle = NSAlertStyleCritical;
                    alert.messageText = @"No microphone access";
                    alert.informativeText = @"Microphone access has been denied, so no audio can be transmitted to the server.";
                    [alert runModal];
                    break;
                }
                case AVAuthorizationStatusRestricted:
                    break;
            }
        } else {
            self.microphoneAvailable = YES;
        }
    }

    self.clientStatus = status;
    self.radioStatus = RadioStatusIdle;
}

- (void)dextraClient:(DExtraClient *)client didReceiveDVPacket:(id)packet {
    if ([packet isKindOfClass:[DVHeaderPacket class]]) {
        self.receiveHeader = (DVHeaderPacket *)packet;
        return;
    }

    DVFramePacket *dvFramePacket = (DVFramePacket *)packet;
    
    if ((self.radioStatus == RadioStatusTransmitting) ||
        !self.receiveHeader ||
        (self.receiveHeader.streamId != dvFramePacket.streamId))
        return;
    if (dvFramePacket.isLast) {
        self.receiveHeader = nil;
        self.radioStatus = RadioStatusIdle;
        return;
    }
    if (self.radioStatus != RadioStatusReceiving) {
        self.statusCheckpoint = [NSDate date];
        self.radioStatus = RadioStatusReceiving;
    } else {
        // Update every 21 packets (packet IDs loop around every 420 ms)
        if (dvFramePacket.packetId == 0)
            self.statusCheckpoint = [NSDate date];
    }
    
    [self.audioPlayerNode scheduleBuffer:[self.dvCodec decodeDSTARFrame:dvFramePacket.dstarFrame] completionHandler:nil];
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
        self.firstConnect = YES;
        [self disconnect];
    }
}

@end
