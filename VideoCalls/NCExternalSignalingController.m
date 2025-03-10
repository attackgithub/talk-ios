//
//  NCExternalSignalingController.m
//  VideoCalls
//
//  Created by Ivan Sein on 07.09.18.
//  Copyright © 2018 struktur AG. All rights reserved.
//

#import "NCExternalSignalingController.h"

#import "SRWebSocket.h"
#import "NCAPIController.h"
#import "NCDatabaseManager.h"
#import "NCRoomsManager.h"
#import "NCSettingsController.h"

static NSTimeInterval kInitialReconnectInterval = 1;
static NSTimeInterval kMaxReconnectInterval     = 16;

@interface NCExternalSignalingController () <SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) NSString* serverUrl;
@property (nonatomic, strong) NSString* ticket;
@property (nonatomic, strong) NSString* resumeId;
@property (nonatomic, strong) NSString* sessionId;
@property (nonatomic, strong) NSString* userId;
@property (nonatomic, strong) NSString* authenticationBackendUrl;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL mcuSupport;
@property (nonatomic, strong) NSMutableDictionary* participantsMap;
@property (nonatomic, strong) NSMutableArray* pendingMessages;
@property (nonatomic, assign) NSInteger reconnectInterval;
@property (nonatomic, strong) NSTimer *reconnectTimer;
@property (nonatomic, assign) BOOL reconnecting;
@property (nonatomic, assign) BOOL sessionChanged;

@end

@implementation NCExternalSignalingController

+ (NCExternalSignalingController *)sharedInstance
{
    static dispatch_once_t once;
    static NCExternalSignalingController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)initWithAccount:(TalkAccount *)account server:(NSString *)serverUrl andTicket:(NSString *)ticket
{
    self = [super init];
    if (self) {
        _account = account;
        _userId = _account.userId;
        _authenticationBackendUrl = [[NCAPIController sharedInstance] authenticationBackendUrlForAccount:_account];
        [self setServer:serverUrl andTicket:ticket];
    }
    return self;
}

- (BOOL)isEnabled
{
    return (_serverUrl) ? YES : NO;
}

- (BOOL)hasMCU
{
    return _mcuSupport;
}

- (NSString *)sessionId
{
    return _sessionId;
}

- (void)setServer:(NSString *)serverUrl andTicket:(NSString *)ticket
{
    _serverUrl = [self getWebSocketUrlForServer:serverUrl];
    _ticket = ticket;
    _processingQueue = dispatch_queue_create("com.nextcloud.Talk.websocket.processing", DISPATCH_QUEUE_SERIAL);
    _reconnectInterval = kInitialReconnectInterval;
    _pendingMessages = [NSMutableArray new];
    
    [self connect];
}

- (NSString *)getWebSocketUrlForServer:(NSString *)serverUrl
{
    NSString *wsUrl = [serverUrl copy];
    
    // Change to websocket protocol
    wsUrl = [wsUrl stringByReplacingOccurrencesOfString:@"https://" withString:@"wss://"];
    wsUrl = [wsUrl stringByReplacingOccurrencesOfString:@"http://" withString:@"ws://"];
    // Remove trailing slash
    if([wsUrl hasSuffix:@"/"]) {
        wsUrl = [wsUrl substringToIndex:[wsUrl length] - 1];
    }
    // Add spreed endpoint
    wsUrl = [wsUrl stringByAppendingString:@"/spreed"];
    
    return wsUrl;
}

#pragma mark - WebSocket connection

- (void)connect
{
    [self invalidateReconnectionTimer];
    _connected = NO;
    NSLog(@"Connecting to: %@",  _serverUrl);
    NSURL *url = [NSURL URLWithString:_serverUrl];
    NSURLRequest *wsRequest = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
    SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURLRequest:wsRequest protocols:@[] allowsUntrustedSSLCertificates:YES];
    [webSocket setDelegateDispatchQueue:self.processingQueue];
    webSocket.delegate = self;
    _webSocket = webSocket;
    
    [_webSocket open];
}

- (void)reconnect
{
    if (_reconnectTimer) {
        return;
    }
    
    [_webSocket close];
    _webSocket = nil;
    _reconnecting = YES;
    
    [self setReconnectionTimer];
}
- (void)forceReconnect
{
    _resumeId = nil;
    [self reconnect];
}

- (void)disconnect
{
    [self invalidateReconnectionTimer];
    [_webSocket close];
    _webSocket = nil;
}

- (void)setReconnectionTimer
{
    [self invalidateReconnectionTimer];
    // Wiggle interval a little bit to prevent all clients from connecting
    // simultaneously in case the server connection is interrupted.
    NSInteger interval = _reconnectInterval - (_reconnectInterval / 2) + arc4random_uniform((int)_reconnectInterval);
    NSLog(@"Reconnecting in %ld", (long)interval);
    dispatch_async(dispatch_get_main_queue(), ^{
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(connect) userInfo:nil repeats:NO];
    });
    _reconnectInterval = _reconnectInterval * 2;
    if (_reconnectInterval > kMaxReconnectInterval) {
        _reconnectInterval = kMaxReconnectInterval;
    }
}

- (void)invalidateReconnectionTimer
{
    [_reconnectTimer invalidate];
    _reconnectTimer = nil;
}

#pragma mark - WebSocket messages

- (void)sendMessage:(NSDictionary *)jsonDict
{
    if (!_connected && ![[jsonDict objectForKey:@"type"] isEqualToString:@"hello"]) {
        [_pendingMessages addObject:jsonDict];
        return;
    }
    
    NSString *jsonString = [self createWebSocketMessage:jsonDict];
    if (!jsonString) {
        NSLog(@"Error creating websobket message");
        return;
    }
    
    NSLog(@"Sending: %@", jsonString);
    [_webSocket send:jsonString];
}

- (void)sendHello
{
    NSDictionary *helloDict = @{
                                @"type": @"hello",
                                @"hello": @{
                                        @"version": @"1.0",
                                        @"auth": @{
                                                @"url": _authenticationBackendUrl,
                                                @"params": @{
                                                        @"userid": _userId,
                                                        @"ticket": _ticket
                                                        }
                                                }
                                        }
                                };
    // Try to resume session
    if (_resumeId) {
        helloDict = @{
                      @"type": @"hello",
                      @"hello": @{
                              @"version": @"1.0",
                              @"resumeid": _resumeId
                              }
                      };
    }
    
    [self sendMessage:helloDict];
}

- (void)helloResponseReceived:(NSDictionary *)helloDict
{
    _connected = YES;
    _resumeId = [helloDict objectForKey:@"resumeid"];
    NSString *newSessionId = [helloDict objectForKey:@"sessionid"];
    _sessionChanged = _sessionId && ![_sessionId isEqualToString:newSessionId];
    _sessionId = newSessionId;
    NSArray *serverFeatures = [[helloDict objectForKey:@"server"] objectForKey:@"features"];
    for (NSString *feature in serverFeatures) {
        if ([feature isEqualToString:@"mcu"]) {
            _mcuSupport = YES;
        }
    }
    
    // Send pending messages
    for (NSDictionary *message in _pendingMessages) {
        [self sendMessage:message];
    }
    _pendingMessages = [NSMutableArray new];
    
    // Re-join if user was in a room
    if (_currentRoom && _sessionChanged) {
        [self.delegate externalSignalingControllerWillRejoinCall:self];
        [[NCRoomsManager sharedInstance] rejoinRoom:_currentRoom];
    }
}

- (void)errorResponseReceived:(NSDictionary *)errorDict
{
    NSString *errorCode = [errorDict objectForKey:@"code"];
    if ([errorCode isEqualToString:@"no_such_session"]) {
        _resumeId = nil;
        [self reconnect];
    }
}

- (void)joinRoom:(NSString *)roomId withSessionId:(NSString *)sessionId
{
    NSDictionary *messageDict = @{
                                  @"type": @"room",
                                  @"room": @{
                                          @"roomid": roomId,
                                          @"sessionid": sessionId
                                          }
                                  };
    
    [self sendMessage:messageDict];
}

- (void)leaveRoom:(NSString *)roomId
{
    if ([_currentRoom isEqualToString:roomId]) {
        _currentRoom = nil;
        [self joinRoom:@"" withSessionId:@""];
    }
}

- (void)sendCallMessage:(NCSignalingMessage *)message
{
    NSDictionary *messageDict = @{
                                  @"type": @"message",
                                  @"message": @{
                                          @"recipient": @{
                                                  @"type": @"session",
                                                  @"sessionid": message.to
                                                  },
                                          @"data": [message functionDict]
                                          }
                                  };
    
    [self sendMessage:messageDict];
}

- (void)requestOfferForSessionId:(NSString *)sessionId andRoomType:(NSString *)roomType
{
    NSDictionary *messageDict = @{
                                  @"type": @"message",
                                  @"message": @{
                                          @"recipient": @{
                                                  @"type": @"session",
                                                  @"sessionid": sessionId
                                                  },
                                          @"data": @{
                                                  @"type": @"requestoffer",
                                                  @"roomType": roomType
                                                  }
                                          }
                                  };
    
    [self sendMessage:messageDict];
}

- (void)roomMessageReceived:(NSDictionary *)messageDict
{
    _participantsMap = [NSMutableDictionary new];
    _currentRoom = [messageDict objectForKey:@"roomid"];
    
    // Notify that session has change to rejoin the call if currently in a call
    if (_sessionChanged) {
        _sessionChanged = NO;
        [self.delegate externalSignalingControllerShouldRejoinCall:self];
    }
}

- (void)eventMessageReceived:(NSDictionary *)eventDict
{
    NSString *eventTarget = [eventDict objectForKey:@"target"];
    if ([eventTarget isEqualToString:@"room"]) {
        [self processRoomEvent:eventDict];
    } else if ([eventTarget isEqualToString:@"roomlist"]) {
        [self processRoomListEvent:eventDict];
    } else if ([eventTarget isEqualToString:@"participants"]) {
        [self processRoomParticipantsEvent:eventDict];
    } else {
        NSLog(@"Unsupported event target: %@", eventDict);
    }
}

- (void)processRoomEvent:(NSDictionary *)eventDict
{
    NSString *eventType = [eventDict objectForKey:@"type"];
    if ([eventType isEqualToString:@"join"]) {
        NSArray *joins = [eventDict objectForKey:@"join"];
        for (NSDictionary *participant in joins) {
            NSString *participantId = [participant objectForKey:@"userid"];
            if (!participantId || [participantId isEqualToString:@""]) {
                NSLog(@"Guest joined room.");
            } else {
                if ([participantId isEqualToString:_userId]) {
                    NSLog(@"App user joined room.");
                } else {
                    [_participantsMap setObject:participant forKey:[participant objectForKey:@"sessionid"]];
                    NSLog(@"Participant joined room.");
                }
            }
        }
    } else if ([eventType isEqualToString:@"leave"]) {
        NSLog(@"Participant left room.");
    } else if ([eventType isEqualToString:@"message"]) {
        [self processRoomMessageEvent:[eventDict objectForKey:@"message"]];
    } else {
        NSLog(@"Unknown room event: %@", eventDict);
    }
}

- (void)processRoomMessageEvent:(NSDictionary *)messageDict
{
    NSString *messageType = [[messageDict objectForKey:@"data"] objectForKey:@"type"];
    if ([messageType isEqualToString:@"chat"]) {
        NSLog(@"Chat message received.");
    } else {
        NSLog(@"Unknown room message type: %@", messageDict);
    }
}

- (void)processRoomListEvent:(NSDictionary *)eventDict
{
    NSLog(@"Refresh room list.");
}

- (void)processRoomParticipantsEvent:(NSDictionary *)eventDict
{
    NSString *eventType = [eventDict objectForKey:@"type"];
    if ([eventType isEqualToString:@"update"]) {
        NSLog(@"Participant list changed: %@", [eventDict objectForKey:@"update"]);
        [self.delegate externalSignalingController:self didReceivedParticipantListMessage:[eventDict objectForKey:@"update"]];
    } else {
        NSLog(@"Unknown room event: %@", eventDict);
    }
}

- (void)messageReceived:(NSDictionary *)messageDict
{
    NSLog(@"Message received");
    [self.delegate externalSignalingController:self didReceivedSignalingMessage:messageDict];
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    if (webSocket == _webSocket) {
        NSLog(@"WebSocket Connected!");
        _reconnectInterval = kInitialReconnectInterval;
        [self sendHello];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)messageData
{
    if (webSocket == _webSocket) {
        NSLog(@"WebSocket didReceiveMessage: %@", messageData);
        NSData *data = [messageData dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *messageDict = [self getWebSocketMessageFromJSONData:data];
        NSString *messageType = [messageDict objectForKey:@"type"];
        if ([messageType isEqualToString:@"hello"]) {
            [self helloResponseReceived:[messageDict objectForKey:@"hello"]];
        } else if ([messageType isEqualToString:@"error"]) {
            [self errorResponseReceived:[messageDict objectForKey:@"error"]];
        } else if ([messageType isEqualToString:@"room"]) {
            [self roomMessageReceived:[messageDict objectForKey:@"room"]];
        } else if ([messageType isEqualToString:@"event"]) {
            [self eventMessageReceived:[messageDict objectForKey:@"event"]];
        } else if ([messageType isEqualToString:@"message"]) {
            [self messageReceived:[messageDict objectForKey:@"message"]];
        }
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (webSocket == _webSocket) {
        NSLog(@"WebSocket didFailWithError: %@", error);
        [self reconnect];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if (webSocket == _webSocket) {
        NSLog(@"WebSocket didCloseWithCode:%ld reason:%@", (long)code, reason);
        [self reconnect];
    }
}

#pragma mark - Utils

- (NSString *)getUserIdFromSessionId:(NSString *)sessionId
{
    NSString *userId = nil;
    NSDictionary *user = [_participantsMap objectForKey:sessionId];
    if (user) {
        userId = [user objectForKey:@"userid"];
    }
    return userId;
}

- (NSDictionary *)getWebSocketMessageFromJSONData:(NSData *)jsonData
{
    NSError *error;
    NSDictionary* messageDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                options:kNilOptions
                                                                  error:&error];
    if (!messageDict) {
        NSLog(@"Error parsing websocket message: %@", error);
    }
    
    return messageDict;
}

- (NSString *)createWebSocketMessage:(NSDictionary *)message
{
    NSError *error;
    NSString *jsonString = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:0
                                                         error:&error];
    
    if (!jsonData) {
        NSLog(@"Error creating websocket message: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return jsonString;
}

@end
