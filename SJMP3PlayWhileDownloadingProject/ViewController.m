//
//  ViewController.m
//  SJMP3PlayWhileDownloadingProject
//
//  Created by BlueDancer on 2017/6/21.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import "ViewController.h"
#import "SJAudioPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) SJAudioPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"\n%@", NSHomeDirectory());

    self.player = [SJAudioPlayer player];
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        /*!
         *  App Transport Security policy
         */
        [self.player playAudioWithPlayURL:@"http://audio.cdn.lanwuzhe.com/1492776280608c177"];

    });
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
