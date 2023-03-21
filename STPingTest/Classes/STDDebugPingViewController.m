//
//  STDDebugPingViewController.m
//  STKitDemo
//
//  Created by SunJiangting on 15-3-9.
//  Copyright (c) 2015年 SunJiangting. All rights reserved.
//

#import "STDDebugPingViewController.h"
#import "STDebugFoundation.h"
#import "STDPingServices.h"
#import <netinet/in.h>
#import <arpa/inet.h>

static void dispatch_async_repeated_internal(dispatch_time_t firstPopTime, double intervalInSeconds, dispatch_queue_t queue, void(^work)(BOOL *stop)) {
    __block bool shouldStop = FALSE;
    dispatch_time_t nextPopTime = dispatch_time(firstPopTime, (int64_t)(intervalInSeconds * NSEC_PER_SEC));
    dispatch_after(nextPopTime, queue, ^{
        work(&shouldStop);
        if(!shouldStop) {
            dispatch_async_repeated_internal(nextPopTime, intervalInSeconds, queue, work);
        }
    });
    
}

static void dispatch_async_repeated(double intervalInSeconds, dispatch_queue_t queue, void(^work)(BOOL *stop)) {
    dispatch_time_t firstPopTime = dispatch_time(DISPATCH_TIME_NOW, intervalInSeconds * NSEC_PER_SEC);
    dispatch_async_repeated_internal(firstPopTime, intervalInSeconds, queue, work);
}

@interface STDDebugPingViewController ()

@property(nonatomic, strong) UITextField        *textField;
@property(nonatomic, strong) STDebugTextView    *textView;
@property(nonatomic, strong) STDPingServices    *pingServices;

@end

@implementation STDDebugPingViewController

- (void)dealloc {
    [self.pingServices cancel];
}

- (void)viewDidLoad {
    CFStringRef hostString = CFSTR("www.baidu.com");
    CFHostRef host = CFHostCreateWithName(CFAllocatorGetDefault(), hostString);
    CFHostStartInfoResolution(host, kCFHostAddresses, NULL);
    CFArrayRef addresses = CFHostGetAddressing(host, NULL);
    for (int i = 0; i< CFArrayGetCount(addresses); i++) {
        struct sockaddr_in * ip;
        ip = (struct sockaddr_in *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addresses, i));
        printf("====:%s\n",inet_ntoa(ip->sin_addr));
    }
    [super viewDidLoad];
    self.navigationItem.title = @"Ping网络";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(_clearDebugViewActionFired:)];
    if ([UIViewController instancesRespondToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout  = UIRectEdgeNone;
    }
    self.view.backgroundColor = [UIColor whiteColor];
    //
    self.textField = [[UITextField alloc] initWithFrame:CGRectMake(10, 10, CGRectGetWidth(self.view.frame) - 100, 30)];
    self.textField.borderStyle = UITextBorderStyleRoundedRect;
    self.textField.placeholder = @"请输入IP地址或者域名";
    self.textField.text = @"www.baidu.com";
    [self.view addSubview:self.textField];
    //
    UIButton *goButton = [UIButton buttonWithType:UIButtonTypeCustom];
    goButton.frame = CGRectMake(CGRectGetMaxX(self.textField.frame) + 10, 10, 60, 30);
    [goButton setTitle:@"Ping" forState:UIControlStateNormal];
    [goButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [goButton addTarget:self action:@selector(_pingActionFired:) forControlEvents:UIControlEventTouchUpInside];
    goButton.tag = 10001;
    [self.view addSubview:goButton];
    //
    self.textView = [[STDebugTextView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.textField.frame) + 10, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame) - CGRectGetMaxY(self.textField.frame) - 10)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.editable = NO;
    [self.view addSubview:self.textView];
}

- (void)_clearDebugViewActionFired:(id)sender {
    self.textView.text = nil;
}

- (void)_pingActionFired:(UIButton *)button {
    [self.textField resignFirstResponder];
    if (button.tag == 10001) {
        __weak STDDebugPingViewController *weakSelf = self;
        [button setTitle:@"Stop" forState:UIControlStateNormal];
        button.tag = 10002;
        __block NSInteger count = 0;
        __block bool finish = false;
        dispatch_async_repeated(4.0, dispatch_get_main_queue(), ^(BOOL *stop) {
            count++;
            self.pingServices = [STDPingServices startPingAddress:self.textField.text callbackHandler:^(STDPingItem *pingItem, NSArray *pingItems) {
                if (pingItem.status != STDPingStatusFinished) {
                    finish = false;
                    [weakSelf.textView appendText:pingItem.description];
                } else {
                    [weakSelf.textView appendText:[STDPingItem statisticsWithPingItems:pingItems]];
                    finish = true;
                    weakSelf.pingServices = nil;
                }
            }];
            self.pingServices.maximumPingTimes = 4;
            if(count >= 1000){
                if(finish){
                    [button setTitle:@"Ping" forState:UIControlStateNormal];
                    button.tag = 10001;
                }
                *stop = TRUE;
            }
        });
    } else {
        [self.pingServices cancel];
    }
    
}

@end
