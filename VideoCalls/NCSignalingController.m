//
//  NCSignalingController.m
//  VideoCalls
//
//  Created by Ivan Sein on 01.10.17.
//  Copyright © 2017 struktur AG. All rights reserved.
//

#import "NCSignalingController.h"

#import "NCAPIController.h"
#import "NCSettingsController.h"
#import <WebRTC/RTCIceServer.h>

@interface NCSignalingController()
{
    NCRoom *_room;
    BOOL _multiRoomSupport;
    BOOL _shouldStopPullingMessages;
    NSTimer *_pingTimer;
    NSDictionary *_signalingSettings;
    NSURLSessionTask *_getSignalingSettingsTask;
    NSURLSessionTask *_pullSignalingMessagesTask;
}

@end

@implementation NCSignalingController

- (instancetype)initForRoom:(NCRoom *)room
{
    self = [super init];
    if (self) {
        _room = room;
        [self checkServerCapabilities];
        [self getSignalingSettings];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"NCSignalingController dealloc");
}

- (void)getSignalingSettings
{
    _getSignalingSettingsTask = [[NCAPIController sharedInstance] getSignalingSettingsForAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:^(NSDictionary *settings, NSError *error) {
        if (error) {
            //TODO: Error handling
            NSLog(@"Error getting signaling settings.");
        }
        
        if (settings) {
            _signalingSettings = [[settings objectForKey:@"ocs"] objectForKey:@"data"];
        }
    }];
}

- (NSArray *)getIceServers
{
    NSMutableArray *servers = [[NSMutableArray alloc] init];
    
    if (_signalingSettings) {
        NSArray *stunServers = [_signalingSettings objectForKey:@"stunservers"];
        for (NSDictionary *stunServer in stunServers) {
            NSString *stunURL = [stunServer objectForKey:@"url"];
            RTCIceServer *iceServer = [[RTCIceServer alloc] initWithURLStrings:@[stunURL]
                                                                     username:@""
                                                                   credential:@""];
            [servers addObject:iceServer];
        }
        NSArray *turnServers = [_signalingSettings objectForKey:@"turnservers"];
        for (NSDictionary *turnServer in turnServers) {
            NSString *turnURL = [turnServer objectForKey:@"url"][0];
            NSString *turnUserName = [turnServer objectForKey:@"username"];
            NSString *turnCredential = [turnServer objectForKey:@"credential"];
            RTCIceServer *iceServer = [[RTCIceServer alloc] initWithURLStrings:@[turnURL]
                                                                      username:turnUserName
                                                                    credential:turnCredential];
            [servers addObject:iceServer];
        }
    }
    
    NSArray *iceServers = [NSArray arrayWithArray:servers];
    return iceServers;
}

- (void)startPullingSignalingMessages
{
    _shouldStopPullingMessages = NO;
    [self pullSignalingMessages];
}

- (void)stopPullingSignalingMessages
{
    _shouldStopPullingMessages = YES;
    [_pullSignalingMessagesTask cancel];
}

- (void)pullSignalingMessages
{
    PullSignalingMessagesCompletionBlock pullSignalingMessagesBlock = ^(NSDictionary *messages, NSError *error)
    {
        if (_shouldStopPullingMessages) {
            return;
        }
        
        id messagesObj = [[messages objectForKey:@"ocs"] objectForKey:@"data"];
        NSArray *messagesArray = [[NSArray alloc] init];
        
        // Check if messages array was parsed correctly
        if ([messagesObj isKindOfClass:[NSArray class]]) {
            messagesArray = messagesObj;
        }else if ([messagesObj isKindOfClass:[NSDictionary class]]) {
            messagesArray = [messagesObj allValues];
        }
        
        for (NSDictionary *message in messagesArray) {
            if ([self.observer respondsToSelector:@selector(signalingController:didReceiveSignalingMessage:)]) {
                [self.observer signalingController:self didReceiveSignalingMessage:message];
            }
        }
        [self pullSignalingMessages];
    };
    
    if (_multiRoomSupport) {
        _pullSignalingMessagesTask = [[NCAPIController sharedInstance] pullSignalingMessagesFromRoom:_room.token forAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:pullSignalingMessagesBlock];
    } else {
        _pullSignalingMessagesTask = [[NCAPIController sharedInstance] pullSignalingMessagesForAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:pullSignalingMessagesBlock];
    }
}

- (void)sendSignalingMessage:(NCSignalingMessage *)message
{
    NSArray *messagesArray = [NSArray arrayWithObjects:[message messageDict], nil];
    NSString *JSONSerializedMessages = [self messagesJSONSerialization:messagesArray];
    
    SendSignalingMessagesCompletionBlock sendSignalingMessagesBlock = ^(NSError *error)
    {
        if (error) {
            //TODO: Error handling
            NSLog(@"Error sending signaling message.");
        }
        NSLog(@"Sent %@", JSONSerializedMessages);
    };
    
    if (_multiRoomSupport) {
        [[NCAPIController sharedInstance] sendSignalingMessages:JSONSerializedMessages toRoom:_room.token forAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:sendSignalingMessagesBlock];
    } else {
        [[NCAPIController sharedInstance] sendSignalingMessages:JSONSerializedMessages forAccount:[[NCDatabaseManager sharedInstance] activeAccount] withCompletionBlock:sendSignalingMessagesBlock];
    }
}

- (NSString *)messagesJSONSerialization:(NSArray *)messages
{
    NSError *error;
    NSString *jsonString = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:messages
                                                       options:0
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return jsonString;
}

- (void)checkServerCapabilities
{
    if ([[NCSettingsController sharedInstance] serverHasTalkCapability:kCapabilityMultiRoomUsers]) {
        _multiRoomSupport = YES;
    }
}

- (void)stopAllRequests
{
    [_getSignalingSettingsTask cancel];
    _getSignalingSettingsTask = nil;
    
    [self stopPullingSignalingMessages];
}

@end
