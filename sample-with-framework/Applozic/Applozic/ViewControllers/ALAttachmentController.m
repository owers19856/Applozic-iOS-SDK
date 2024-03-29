//
//  ALImageWithTextController.m
//  ChatApp
//
//  Created by devashish on 31/10/2015.
//  Copyright © 2015 AppLogic. All rights reserved.
//

#import "ALAttachmentController.h"

@interface ALAttachmentController ()

@end

@implementation ALAttachmentController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.pickedImageView setImage:self.imagedocument];
    self.imageText.delegate = self;
}

-(void)viewWillAppear:(BOOL)animated{
    
    self.imageText.layer.masksToBounds=YES;
    self.imageText.layer.borderColor=[[UIColor brownColor] CGColor];
    self.imageText.layer.borderWidth=1.0f;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cancelButtonAction:(id)sender {
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)sendButtonAction:(id)sender {
 
    [self.imagecontrollerDelegate check:self.imagedocument andText:self.imageText.text];
    [self.navigationController popViewControllerAnimated:YES];
}

-(void) setImageViewMethod:(UIImage *)image {
    self.imagedocument = image;
}

#pragma mark - Text Field Delegate

-(BOOL) textFieldShouldReturn:(UITextField *)textField {
    
    [self.imageText resignFirstResponder];
    return  YES;
}

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    
    UITouch* touch=[[event allTouches] anyObject];
    if([self.imageText isFirstResponder]&&[touch view]!=self.imageText){
        [self.imageText resignFirstResponder];
        
    }
}
-(void) viewDidDisappear:(BOOL)animated{

}
@end
