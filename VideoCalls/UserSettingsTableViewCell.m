//
//  UserSettingsTableViewCell.m
//  VideoCalls
//
//  Created by Ivan Sein on 16.01.18.
//  Copyright © 2018 struktur AG. All rights reserved.
//

#import "UserSettingsTableViewCell.h"

NSString *const kUserSettingsCellIdentifier = @"UserSettingsCellIdentifier";
NSString *const kUserSettingsTableCellNibName = @"UserSettingsTableViewCell";

@implementation UserSettingsTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.userImageView.layer.cornerRadius = 40.0;
    self.userImageView.layer.masksToBounds = YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
