//
//  ALMQTTConversationService.m
//  Applozic
//
//  Created by Applozic Inc on 11/27/15.
//  Copyright © 2015 applozic Inc. All rights reserved.
//

#import "ALMQTTConversationService.h"
#import "MQTTSession.h"
#import "ALUserDefaultsHandler.h"
#import "ALConstant.h"
#import "ALMessage.h"
#import "ALMessageDBService.h"

@implementation ALMQTTConversationService

static MQTTSession *session;

+(ALMQTTConversationService *)sharedInstance
{
    static ALMQTTConversationService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ALMQTTConversationService alloc] init];
    });
    return sharedInstance;
}

-(void) subscribeToConversation {
    if (![ALUserDefaultsHandler isLoggedIn]) {
        return;
    }
    NSLog(@"connecting to mqtt server");
    
    session = [[MQTTSession alloc]initWithClientId:[NSString stringWithFormat:@"%@-%f",
                                                    [ALUserDefaultsHandler getUserKeyString],fmod([[NSDate date] timeIntervalSince1970], 10.0)]];
    session.willFlag = TRUE;
    session.willTopic = @"status";
    session.willMsg = [[NSString stringWithFormat:@"%@,%@", [ALUserDefaultsHandler getUserKeyString], @"0"] dataUsingEncoding:NSUTF8StringEncoding];
    session.willQoS = MQTTQosLevelAtMostOnce;
    [session setDelegate:self];
    NSLog(@"waiting for connect...");
    
    [session connectToHost:MQTT_URL port:[MQTT_PORT intValue] withConnectionHandler:^(MQTTSessionEvent event) {
        if (event == MQTTSessionEventConnected) {
            NSLog(@"MQTT: Subscribing to conversation topics.");
            [session subscribeToTopic:[ALUserDefaultsHandler getUserKeyString] atLevel:MQTTQosLevelAtMostOnce];
            [session subscribeToTopic:[NSString stringWithFormat:@"typing-%@-%@", [ALUserDefaultsHandler getApplicationKey], [ALUserDefaultsHandler getUserId]] atLevel:MQTTQosLevelAtMostOnce];
        }
    } messageHandler:^(NSData *data, NSString *topic) {
        
    }];
    
    NSLog(@"MQTT: connected...");
    
    /*if (session.status == MQTTSessionStatusConnected) {
     [session subscribeToTopic:[ALUserDefaultsHandler getUserKeyString] atLevel:MQTTQosLevelAtMostOnce];
     }*/
}

- (void)session:(MQTTSession*)session newMessage:(NSData*)data onTopic:(NSString*)topic {
    NSLog(@"MQTT got new message");
}

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid
{
    NSString *fullMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"MQTT got new message: %@", fullMessage);

    NSError *error = nil;
    NSDictionary *theMessageDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSString *type = [theMessageDict objectForKey:@"type"];
    NSString *instantMessageJson = [theMessageDict objectForKey:@"message"];
    
    if ([topic hasPrefix:@"typing"]) {
        NSArray *typingParts = [fullMessage componentsSeparatedByString:@","];
        NSString *applicationKey = typingParts[0]; //Note: will get used once we support messaging from one app to another
        NSString *userId = typingParts[1];
        BOOL typingStatus = [typingParts[2] boolValue];
        [self.mqttConversationDelegate updateTypingStatus:applicationKey userId:userId status:typingStatus];
    } else {
        /*if ([type isEqualToString:@"MESSAGE_DELIVERED_READ"]) {
            NSLog(@"mark as read and delivered");
        } else*/
        if ([type isEqualToString:@"MESSAGE_DELIVERED"] || [type isEqualToString:@"MESSAGE_DELIVERED_READ"]) {
            NSArray *deliveryParts = [[theMessageDict objectForKey:@"message"] componentsSeparatedByString:@","];
            ALMessageDBService* messageDBService = [[ALMessageDBService alloc] init];
            [messageDBService updateMessageDeliveryReport:deliveryParts[0]];
            NSLog(@"delivery report for %@", deliveryParts[0]);
            [self.mqttConversationDelegate delivered: deliveryParts[0] contactId:deliveryParts[1]];
        } else if ([type isEqualToString: @"MESSAGE_RECEIVED"]) {
            NSData *messageData = [instantMessageJson
                                   dataUsingEncoding:NSUTF8StringEncoding];
            
            id result = [NSJSONSerialization JSONObjectWithData:messageData
                                                        options:NSJSONReadingAllowFragments
                                                          error:NULL];
            ALMessage *alMessage = [[ALMessage alloc] initWithDictonary:result];
            [self.mqttConversationDelegate syncCall: alMessage];
        }
    }
  
}

- (void)subAckReceived:(MQTTSession *)session msgID:(UInt16)msgID grantedQoss:(NSArray *)qoss
{
    NSLog(@"subscribed");
}

- (void)connected:(MQTTSession *)session {
    
}

- (void)connectionClosed:(MQTTSession *)session {
    NSLog(@"MQTT connection closed");
    [self.mqttConversationDelegate mqttConnectionClosed];

    //Todo: inform controller about connection closed.
}

- (void)handleEvent:(MQTTSession *)session
              event:(MQTTSessionEvent)eventCode
              error:(NSError *)error {
}

- (void)received:(MQTTSession *)session type:(int)type qos:(MQTTQosLevel)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data {
    
}

-(void) sendTypingStatus:(NSString *) applicationKey userID:(NSString *) userId typing: (BOOL) typing;
{
     NSLog(@"Received typing status in MQTTCONVERSationSERvice  %d for: %@", typing, userId);
    NSData* data=[[NSString stringWithFormat:@"%@,%@,%i", [ALUserDefaultsHandler getApplicationKey],userId, typing ? 1 : 0] dataUsingEncoding:NSUTF8StringEncoding];
    [session publishDataAtMostOnce:data onTopic:[NSString stringWithFormat:@"typing-%@-%@", [ALUserDefaultsHandler getApplicationKey], [ALUserDefaultsHandler getUserId]]];
}

@end