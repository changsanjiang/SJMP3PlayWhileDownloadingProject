//
//  ViewController.m
//  SJMP3PlayWhileDownloadingProject
//
//  Created by BlueDancer on 2017/6/21.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import "ViewController.h"
#import "SJMP3Player.h"

@interface ViewController ()

@property (nonatomic, strong) SJMP3Player *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"\n%@", NSHomeDirectory());

    self.player = [SJMP3Player player];
    

    /*!
     *  App Transport Security policy
     */
    [self.player playAudioWithPlayURL:@"http://audio.cdn.lanwuzhe.com/1492776280608c177"];


    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
