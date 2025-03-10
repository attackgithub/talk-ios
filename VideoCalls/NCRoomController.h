//
//  NCRoomController.h
//  VideoCalls
//
//  Created by Ivan Sein on 23.05.18.
//  Copyright © 2018 struktur AG. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NCRoomController;

extern NSString * const NCRoomControllerDidReceiveInitialChatHistoryNotification;
extern NSString * const NCRoomControllerDidReceiveChatHistoryNotification;
extern NSString * const NCRoomControllerDidReceiveChatMessagesNotification;
extern NSString * const NCRoomControllerDidSendChatMessageNotification;
extern NSString * const NCRoomControllerDidReceiveChatBlockedNotification;

@interface NCRoomController : NSObject

@property (nonatomic, strong) NSString *userSessionId;
@property (nonatomic, strong) NSString *roomToken;
@property (nonatomic, assign) BOOL inCall;
@property (nonatomic, assign) BOOL inChat;
@property (nonatomic, assign) BOOL hasHistory;

- (instancetype)initForUser:(NSString *)sessionId inRoom:(NSString *)token;
- (void)startPingRoom;
- (void)stopPingRoom;
- (void)sendChatMessage:(NSString *)message;
- (void)getInitialChatHistory:(NSInteger)lastReadMessage;
- (void)getChatHistoryFromMessagesId:(NSInteger)messageId;
- (void)startReceivingChatMessagesFromMessagesId:(NSInteger)messageId withTimeout:(BOOL)timeout;
- (void)stopReceivingChatMessages;
- (void)stopRoomController;

@end
