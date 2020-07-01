//
//  BTDetailViewController.m
//  BetaDataSDK_Example
//
//  Created by ZK on 2019/7/23.
//  Copyright © 2019 zk_520it@163.com. All rights reserved.
//

#import "BTDetailViewController.h"

@interface BTDetailViewController ()

@end

@implementation BTDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"详情页面";
}

- (IBAction)popBtnAction {
    [self.navigationController popViewControllerAnimated:true];
}

@end
