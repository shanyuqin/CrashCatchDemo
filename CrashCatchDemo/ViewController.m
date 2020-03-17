//
//  ViewController.m
//  CrashCatchDemo
//
//  Created by ShanYuQin on 2020/3/17.
//  Copyright © 2020 ShanYuQin. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"点击就异常" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(100, 100, 100, 20);
    [self.view addSubview:button];
}

- (void)buttonClick{
    id array = @[@"myBlog",@"lemon2Well.top"];
    [array objectAtIndex:3];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"干别的");
}

@end
