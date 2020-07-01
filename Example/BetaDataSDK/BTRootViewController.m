//
//  BTRootViewController.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 04/11/2019.
//  Copyright (c) 2019 Zhou Kang. All rights reserved.
//

#import "BTRootViewController.h"
#import "BTDetailViewController.h"
#import "BetaDataSDK.h"

@interface BTRootViewController ()

@end

@implementation BTRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"主页面";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)enterBtnAction {
    BTDetailViewController *vc = [BTDetailViewController new];
    [self.navigationController pushViewController:vc animated:true];
}

- (IBAction)loginAction {
    [[BetaDataSDK sharedInstance] login:@"rc_10086"];
}

- (IBAction)logoutAction {
    [[BetaDataSDK sharedInstance] logout];
}

@end
