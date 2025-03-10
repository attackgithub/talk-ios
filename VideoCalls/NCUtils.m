//
//  NCUtils.m
//  VideoCalls
//
//  Created by Ivan Sein on 24.04.19.
//  Copyright © 2019 struktur AG. All rights reserved.
//

#import "NCUtils.h"

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "NCDatabaseManager.h"

static NSString *const nextcloudScheme = @"nextcloud:";

@implementation NCUtils

+ (NSString *)previewImageForFileExtension:(NSString *)fileExtension
{
    CFStringRef fileExtensionSR = (__bridge CFStringRef)fileExtension;
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtensionSR, NULL);
    return [self previewImageForFileType:fileUTI];
}

+ (NSString *)previewImageForFileMIMEType:(NSString *)fileMIMEType
{
    CFStringRef fileMIMETypeSR = (__bridge CFStringRef)fileMIMEType;
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, fileMIMETypeSR, NULL);
    if (!UTTypeIsDeclared(fileUTI)) {
        // Folders
        if ([fileMIMEType isEqualToString:@"httpd/unix-directory"]) {
            return @"folder";
        }
        // Default
        return @"file";
    }
    return [self previewImageForFileType:fileUTI];
}

+ (NSString *)previewImageForFileType:(CFStringRef)fileType
{
    NSString *previewImage = @"file";
    if (fileType) {
        if (UTTypeConformsTo(fileType, kUTTypeAudio)) previewImage = @"file-audio";
        else if (UTTypeConformsTo(fileType, kUTTypeMovie)) previewImage = @"file-video";
        else if (UTTypeConformsTo(fileType, kUTTypeImage)) previewImage = @"file-image";
        else if (UTTypeConformsTo(fileType, kUTTypeSpreadsheet)) previewImage = @"file-spreadsheet";
        else if (UTTypeConformsTo(fileType, kUTTypePresentation)) previewImage = @"file-presentation";
        else if (UTTypeConformsTo(fileType, kUTTypePDF)) previewImage = @"file-pdf";
        else if (UTTypeConformsTo(fileType, kUTTypeText)) previewImage = @"file-text";
        else if ([(__bridge NSString *)fileType containsString:@"org.openxmlformats"] || [(__bridge NSString *)fileType containsString:@"org.oasis-open.opendocument"]) previewImage = @"file-document";
        else if (UTTypeConformsTo(fileType, kUTTypeZipArchive)) previewImage = @"file-zip";
    }
    return previewImage;
}

 + (BOOL)isNextcloudAppInstalled
{
    NSURL *url = [NSURL URLWithString:nextcloudScheme];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

+ (void)openFileInNextcloudApp:(NSString *)path withFileLink:(NSString *)link
{
    if (![self isNextcloudAppInstalled]) {
        return;
    }
    TalkAccount *activeAccount = [[NCDatabaseManager sharedInstance] activeAccount];
    NSString *nextcloudURLString = [NSString stringWithFormat:@"%@//open-file?path=%@&user=%@&link=%@", nextcloudScheme, path, activeAccount.user, link];
    NSURL *nextcloudURL = [NSURL URLWithString:[nextcloudURLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    [[UIApplication sharedApplication] openURL:nextcloudURL options:@{} completionHandler:nil];
}

+ (NSDate *)dateFromDateAtomFormat:(NSString *)dateAtomFormatString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    return [dateFormatter dateFromString:dateAtomFormatString];
}
+ (NSString *)dateAtomFormatFromDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    
    return [dateFormatter stringFromDate:date];
}
+ (NSString *)readableDateFromDate:(NSDate *)date
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    return [dateFormatter stringFromDate:date];
}

@end
