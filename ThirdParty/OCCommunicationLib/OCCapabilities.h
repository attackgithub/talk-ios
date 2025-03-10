//
//  OCCapabilities.h
//  ownCloud iOS library
//
//  Created by Gonzalo Gonzalez on 4/11/15.
//  Copyright © 2015 ownCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCCapabilities : NSObject

/*VERSION*/
@property (nonatomic) NSInteger versionMajor;
@property (nonatomic) NSInteger versionMinor;
@property (nonatomic) NSInteger versionMicro;
@property (nonatomic, strong) NSString *versionString;
@property (nonatomic, strong) NSString *versionEdition;

/*CAPABILITIES*/

/*CORE*/
@property (nonatomic) NSInteger corePollInterval;

/*FILES SHARING*/

@property (nonatomic) BOOL isFilesSharingAPIEnabled;

//SHARE LINK FEATURES
@property (nonatomic) BOOL isFilesSharingShareLinkEnabled;

//Share Link with password
@property (nonatomic) BOOL isFilesSharingPasswordEnforcedEnabled;

//Share Link with expiration date
@property (nonatomic) BOOL isFilesSharingExpireDateByDefaultEnabled;
@property (nonatomic) BOOL isFilesSharingExpireDateEnforceEnabled;
@property (nonatomic) NSInteger filesSharingExpireDateDaysNumber;

//Other share link features
@property (nonatomic) BOOL isFilesSharingAllowUserSendMailNotificationAboutShareLinkEnabled;
@property (nonatomic) BOOL isFilesSharingAllowPublicUploadsEnabled;

//Other Shares Features
@property (nonatomic) BOOL isFilesSharingAllowUserSendMailNotificationAboutOtherUsersEnabled;
@property (nonatomic) BOOL isFilesSharingReSharingEnabled;

//Federating cloud share (before called Server-to-Server sharing)
@property (nonatomic) BOOL isFilesSharingAllowUserSendSharesToOtherServersEnabled;
@property (nonatomic) BOOL isFilesSharingAllowUserReceiveSharesToOtherServersEnabled;

// External sites
@property (nonatomic) BOOL isExternalSitesServerEnabled;
@property (nonatomic, strong) NSString *externalSiteV1;

// Notification
@property (nonatomic) BOOL isNotificationServerEnabled;
@property (nonatomic, strong) NSString *notificationOcsEndpoints;
@property (nonatomic, strong) NSString *notificationPush;

// Spreed
@property (nonatomic) BOOL isSpreedServerEnabled;
@property (nonatomic, strong) NSString *spreedFeatures;

/*FILES*/
@property (nonatomic) BOOL isFileBigFileChunkingEnabled;
@property (nonatomic) BOOL isFileUndeleteEnabled;
@property (nonatomic) BOOL isFileVersioningEnabled;

// Theming
@property (nonatomic, strong) NSString *themingBackground;
@property (nonatomic) BOOL themingBackgroundDefault;
@property (nonatomic) BOOL themingBackgroundPlain;
@property (nonatomic, strong) NSString *themingColor;
@property (nonatomic, strong) NSString *themingColorElement;
@property (nonatomic, strong) NSString *themingColorText;
@property (nonatomic, strong) NSString *themingLogo;
@property (nonatomic, strong) NSString *themingName;
@property (nonatomic, strong) NSString *themingSlogan;
@property (nonatomic, strong) NSString *themingUrl;

// End to End Encryption
@property (nonatomic) BOOL isEndToEndEncryptionEnabled;
@property (nonatomic, strong) NSString *endToEndEncryptionVersion;

// Richdocuments
@property (nonatomic, strong) NSArray *richdocumentsMimetypes;
@property (nonatomic) BOOL richdocumentsDirectEditing;

// Activity
@property (nonatomic) BOOL isActivityV2Enabled;
@property (nonatomic, strong) NSString *activityV2;

@end
