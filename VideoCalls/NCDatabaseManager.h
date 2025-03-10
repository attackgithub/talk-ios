//
//  NCDatabaseManager.h
//  VideoCalls
//
//  Created by Ivan Sein on 08.05.19.
//  Copyright © 2019 struktur AG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

NS_ASSUME_NONNULL_BEGIN

@interface TalkAccount : RLMObject
@property NSString *accountId;
@property NSString *server;
@property NSString *user;
@property NSString *userId;
@property NSString *userDisplayName;
@property BOOL pushNotificationSubscribed;
@property NSData *pushNotificationPublicKey;
@property NSString *deviceIdentifier;
@property NSString *deviceSignature;
@property NSString *userPublicKey;
@property BOOL active;
@end

@interface ServerCapabilities : RLMObject
@property NSString *accountId;
@property NSString *name;
@property NSString *slogan;
@property NSString *url;
@property NSString *logo;
@property NSString *color;
@property NSString *colorElement;
@property NSString *colorText;
@property NSString *background;
@property BOOL backgroundDefault;
@property BOOL backgroundPlain;
@property NSString *version;
@property NSInteger versionMajor;
@property NSInteger versionMinor;
@property NSInteger versionMicro;
@property NSString *edition;
@property BOOL extendedSupport;
@property RLMArray<RLMString> *talkCapabilities;
@property NSInteger chatMaxLength;
@end

@interface NCDatabaseManager : NSObject

+ (instancetype)sharedInstance;

- (NSInteger)numberOfAccounts;
- (TalkAccount *)activeAccount;
- (RLMResults *)nonActiveAccounts;
- (TalkAccount *)talkAccountForAccountId:(NSString *)accountId;
- (void)setActiveAccount:(NSString *)accountId;
- (NSString *)accountIdForUser:(NSString *)user inServer:(NSString *)server;
- (void)createAccountForUser:(NSString *)user inServer:(NSString *)server;
- (void)removeAccount:(NSString *)accountId;

- (ServerCapabilities *)serverCapabilitiesForAccountId:(NSString *)accountId;
- (void)setServerCapabilities:(NSDictionary *)serverCapabilities forAccountId:(NSString *)accountId;

@end

NS_ASSUME_NONNULL_END
