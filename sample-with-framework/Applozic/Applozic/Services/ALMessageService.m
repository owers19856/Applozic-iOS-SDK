//
//  ALMessageService.m
//  ALChat
//
//  Copyright (c) 2015 AppLozic. All rights reserved.
//

#import "ALMessageService.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALUtilityClass.h"
#import "ALSyncMessageFeed.h"
#import "ALMessageDBService.h"
#import "ALMessageList.h"
#import "ALDBHandler.h"
#import "ALConnection.h"
#import "ALConnectionQueueHandler.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageClientService.h"
#import "ALSendMessageResponse.h"
#import "ALUserService.h"
#import "ALUserDetail.h"

@implementation ALMessageService

+(void) getMessagesListGroupByContactswithCompletion:(void(^)(NSMutableArray * messages, NSError * error)) completion {
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/list",KBASE_URL];
    
    NSString * theParamString = [NSString stringWithFormat:@"startIndex=%@",@"0"];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"GET MESSAGES GROUP BY CONTACT" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
       
        ALMessageList *messageListResponse =  [[ALMessageList alloc] initWithJSONString:theJson] ;
        
        completion(messageListResponse.messageList,nil);
        //NSLog(@"message list response THE JSON %@",theJson);
//        [ALUserService processContactFromMessages:[messageListResponse messageList]];
    }];
    
}

+(void)getMessageListForUser:(NSString *)userId startIndex:(NSString *)startIndex pageSize:(NSString *)pageSize endTimeInTimeStamp:(NSString *)endTimeStamp withCompletion:(void (^)(NSMutableArray *, NSError *))completion
{
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/list",KBASE_URL];
    
    NSString * theParamString = [NSString stringWithFormat:@"userId=%@&startIndex=%@&pageSize=%@&endTime=%@",userId,startIndex,pageSize,endTimeStamp];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"GET MESSAGES LIST FOR USERID" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        ALMessageList *messageListResponse=  [[ALMessageList alloc] initWithJSONString:theJson];
        
        completion(messageListResponse.messageList,nil);
       // NSLog(@"message list response THE JSON %@",theJson);
    }];
    
}
//(ALMessage *)userInfo withCompletion:(void(^)(NSString * message, NSError * error)) completion

+(void) sendMessages:(ALMessage *)alMessage withCompletion:(void(^)(NSString * message, NSError * error)) completion {
    
    //DB insert if objectID is null
    DB_Message* dbMessage;
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    NSError *theError=nil;
    [[ NSNotificationCenter defaultCenter] postNotificationName:@"updateConversationTableNotification" object:alMessage userInfo:nil];

    if (alMessage.msgDBObjectId==nil){
        NSLog(@"message not in DB new insertion.");

        dbMessage =[dbService addMessage:alMessage];
    }else{
        NSLog(@"message found in DB just getting it not inserting new one...");
        dbMessage =(DB_Message*)[dbService getMeesageById:alMessage.msgDBObjectId error:&theError];
    }
       //convert to dic
    NSDictionary * userInfo = [alMessage dictionary ];
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/send",KBASE_URL];
    NSString * theParamString = [ALUtilityClass generateJsonStringFromDictionary:userInfo];
   
    NSMutableURLRequest * theRequest = [ALRequestHandler createPOSTRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"SEND MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        NSString *statusStr = (NSString *)theJson;
        //TODO: move to db layer
        ALSendMessageResponse  *response = [[ALSendMessageResponse alloc] initWithJSONString:statusStr ];

        ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
        dbMessage.isSent = [NSNumber numberWithBool:YES];
        dbMessage.key = response.messageKey;
        dbMessage.inProgress = [NSNumber numberWithBool:NO];
        dbMessage.isUploadFailed = [NSNumber numberWithBool:NO];

        dbMessage.createdAt =response.createdAt;
        alMessage.key = dbMessage.key;
        dbMessage.sentToServer=[NSNumber numberWithBool:YES];
        dbMessage.isRead=[NSNumber numberWithBool:YES];
        
        alMessage.key = dbMessage.key;
        alMessage.sentToServer= dbMessage.sentToServer.boolValue;
        alMessage.inProgress=dbMessage.inProgress.boolValue;
        alMessage.isUploadFailed=dbMessage.isUploadFailed.boolValue;
        alMessage.sent = dbMessage.isSent.boolValue;

        [theDBHandler.managedObjectContext save:nil];
        completion(statusStr,nil);
        
    }];
    
}

+(void) sendPhotoForUserInfo:(NSDictionary *)userInfo withCompletion:(void(^)(NSString * message, NSError *error)) completion {
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/aws/file/url",KBASE_FILE_URL];

    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:nil];
    
    [ALResponseHandler processRequest:theRequest andTag:@"CREATE FILE URL" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        NSString *imagePostingURL = (NSString *)theJson;
    
        completion(imagePostingURL,nil);
        
    }];
}


+(void) getLatestMessageForUser:(NSString *)deviceKeyString withCompletion:(void (^)( NSMutableArray *, NSError *))completion{
    @synchronized(self) {
        NSString *lastSyncTime =[ALUserDefaultsHandler
                                 getLastSyncTime ];
        if ( lastSyncTime == NULL ){
            lastSyncTime = @"0";
        }
        NSLog(@"last syncTime in call %@", lastSyncTime);
        NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/sync",KBASE_URL];
    
        NSString * theParamString = [NSString stringWithFormat:@"lastSyncTime=%@",lastSyncTime];
        
        NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
        
        [ALResponseHandler processRequest:theRequest andTag:@"SYNC LATEST MESSAGE URL" WithCompletionHandler:^(id theJson, NSError *theError) {
            
            if (theError) {
                
                completion(nil,theError);
                
                return ;
            }
            
            NSMutableArray *messageArray = [[NSMutableArray alloc] init];
            ALSyncMessageFeed *syncResponse =  [[ALSyncMessageFeed alloc] initWithJSONString:theJson];
            NSLog(@"count is: %lu", (unsigned long)syncResponse.messagesList.count);
            if(syncResponse.messagesList.count >0 ){
                ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
                messageArray = [dbService addMessageList:syncResponse.messagesList];
               // [ALUserService processContactFromMessages:syncResponse.messageList];
            }
            
            if (syncResponse.deliveredMessageKeys.count > 0) {
                [ALMessageService updateDeliveredReport: syncResponse.deliveredMessageKeys];
            }
            [ALUserDefaultsHandler setLastSyncTime:syncResponse.lastSyncTime];
            ALMessageClientService *messageClientService = [[ALMessageClientService alloc] init];
            [messageClientService updateDeliveryReports:syncResponse.messagesList];
            completion(messageArray, nil);
        }];

    }
    
  }

+(void) updateDeliveredReport: (NSArray *) deliveredMessageKeys {
    for (id key in deliveredMessageKeys) {
        ALMessageDBService* messageDBService = [[ALMessageDBService alloc] init];
        [messageDBService updateMessageDeliveryReport:key];
    }
}

+(void )deleteMessage:( NSString * ) keyString andContactId:( NSString * )contactId withCompletion:(void (^)(NSString *, NSError *))completion{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/delete",KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"key=%@&userId=%@",keyString,contactId];
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"DELETE_MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        NSLog(@"Response of delete: %@", (NSString *)theJson);
        completion((NSString *)theJson,nil);
        
    }];
}


+(void)deleteMessageThread:( NSString * ) contactId withCompletion:(void (^)(NSString *, NSError *))completion{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/delete/conversation",KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"userId=%@",contactId];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"DELETE_MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        if (theError) {
            completion(nil,theError);
            NSLog(@"theError");
            return ;
        }else{
            //delete sucessfull
            NSLog(@"sucessfully deleted !");
            ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
            [dbService deleteAllMessagesByContact:contactId];
        }
        NSLog(@"Response of delete: %@", (NSString *)theJson);
        completion((NSString *)theJson,nil);
    }];
}


+(void) proessUploadImageForMessage:(ALMessage *)message databaseObj:(DB_FileMetaInfo *)fileMetaInfo uploadURL:(NSString *)uploadURL withdelegate:(id)delegate{
    
   
    NSString * docDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * timestamp = message.imageFilePath;
    NSString * filePath = [docDirPath stringByAppendingPathComponent:timestamp];
    NSMutableURLRequest * request = [ALRequestHandler createPOSTRequestWithUrlString:uploadURL paramString:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        //Create boundary, it can be anything
        NSString *boundary = @"------ApplogicBoundary4QuqLuM1cE5lMwCy";
        // set Content-Type in HTTP header
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
        // post body
        NSMutableData *body = [NSMutableData data];
        //Populate a dictionary with all the regular values you would like to send.
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        // add params (all params are strings)
        for (NSString *param in parameters) {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"%@\r\n", [parameters objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        NSString *FileParamConstant = @"files[]";
        NSData *imageData = [[NSData alloc]initWithContentsOfFile:filePath];
        NSLog(@"%f",imageData.length/1024.0);
        //Assuming data is not nil we add this to the multipart form
        if (imageData)
        {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", FileParamConstant,message.fileMeta.name] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Type:image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:imageData];
            [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        //Close off the request with the boundary
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        // setting the body of the post to the request
        [request setHTTPBody:body];
        // set URL
        [request setURL:[NSURL URLWithString:uploadURL]];
        NSMutableArray * theCurrentConnectionsArray = [[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue];
        NSArray * theFiletredArray = [theCurrentConnectionsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"keystring == %@", message.key]];
        
        if( theFiletredArray.count>0 ){
            NSLog(@"upload is already running .....not starting new one ....");
            return;
        }
        ALConnection * connection = [[ALConnection alloc] initWithRequest:request delegate:delegate startImmediately:YES];
        connection.keystring =message.key;
        connection.connectionType = @"Image Posting";
        [[[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue] addObject:connection];
    
    }
  
}
+(void) processImageDownloadforMessage:(ALMessage *) message withdelegate:(id)delegate{
    NSString * urlString = [NSString stringWithFormat:@"%@/rest/ws/aws/file/%@",KBASE_FILE_URL,message.fileMeta.blobKey];
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:urlString paramString:nil];
    ALConnection * connection = [[ALConnection alloc] initWithRequest:theRequest delegate:delegate startImmediately:YES];
    connection.keystring = message.key;
    connection.connectionType = @"Image Downloading";
    [[[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue] addObject:connection];
}

+(ALMessage*) processFileUploadSucess: (ALMessage *) message{
    
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    DB_Message *dbMessage =  (DB_Message*)[dbService getMessageByKey:@"key" value:message.key];
    
    dbMessage.fileMetaInfo.blobKeyString = message.fileMeta.blobKey;
    dbMessage.fileMetaInfo.contentType = message.fileMeta.contentType;
    dbMessage.fileMetaInfo.createdAtTime = message.fileMeta.createdAtTime;
    dbMessage.fileMetaInfo.key = message.fileMeta.key;
    dbMessage.fileMetaInfo.name = message.fileMeta.name;
    dbMessage.fileMetaInfo.size = message.fileMeta.size;
    dbMessage.fileMetaInfo.suUserKeyString = message.fileMeta.userKey;
    message.fileMetaKey = message.fileMeta.key;
    [[ALDBHandler sharedInstance].managedObjectContext save:nil];
    return message;
}

+(void)markConversationAsRead: (NSString *) contactId withCompletion:(void (^)(NSString *, NSError *))completion{
    
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    
    NSUInteger count = [dbService markConversationAsRead:contactId];
    NSLog(@"Found %ld messages for marking as read.", count);
    
    if(count == 0)
    {
        return;
    }
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/read/conversation",KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"userId=%@",contactId];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"MARK_CONVERSATION_AS_READ" WithCompletionHandler:^(id theJson, NSError *theError) {
        if (theError) {
            completion(nil,theError);
            NSLog(@"theError");
            return ;
        }else{
            //read sucessfull
            NSLog(@"sucessfully marked read !");
        }
        NSLog(@"Response: %@", (NSString *)theJson);
        completion((NSString *)theJson,nil);
    }];
}

+(void)userDetailServerCall:(NSString *)contactId withCompletion:(void(^)(ALUserDetail *))completionMark
{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/user/detail",KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"userIds=%@",contactId];
    
    NSLog(@"calling last seen at api for userIds: %@", contactId);
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"USER_LAST_SEEN" WithCompletionHandler:^(id theJson, NSError *theError) {
        if (theError)
        {
            NSLog(@"ERROR IN LAST SEEN %@", theError);
        }
        else
        {
          // NSLog(@"SEVER RESPONSE FROM JSON : %@", (NSString *)theJson);
           ALUserDetail *userDetailObject = [[ALUserDetail alloc] initWithJSONString:theJson];
          // [userDetailObject userDetail];
         completionMark(userDetailObject);
            
        }
        

    }];
    
    
}

@end
