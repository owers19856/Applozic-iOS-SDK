//
//  ALChatViewController.h
//  ChatApp
//
//  Copyright (c) 2015 AppLozic. All rights reserved.
//
#import "ALMapViewController.h"
#import <UIKit/UIKit.h>
#import "ALMessage.h"
#import "ALBaseViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "DB_CONTACT.h"
#import "ALContact.h"
#import "ALChatCell.h"

@interface ALChatViewController : ALBaseViewController<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate,UIActionSheetDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,ALMapViewControllerDelegate,ALChatCellDelegate>

@property (strong, nonatomic) ALContact *alContact;
@property (strong, nonatomic) NSMutableArray *mMessageListArray;
@property (strong, nonatomic) NSMutableArray *mMessageListArrayKeyStrings;
@property (strong, nonatomic) NSString * contactIds;
@property (nonatomic) BOOL refreshMainView;
@property (nonatomic) BOOL refresh;

-(void)fetchAndRefresh;

-(void)updateDeliveryReport:(NSString*)keyString;

-(void)individualNotificationhandler:(NSNotification *) notification;

-(void)updateDeliveryStatus:(NSNotification *) notification;


@end
