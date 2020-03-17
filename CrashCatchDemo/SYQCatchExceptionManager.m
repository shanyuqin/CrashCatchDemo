//
//  SYQCatchExceptionManager.m
//  CrashCatchDemo
//
//  Created by ShanYuQin on 2020/3/17.
//  Copyright © 2020 ShanYuQin. All rights reserved.
//

#import "SYQCatchExceptionManager.h"
#import <UIKit/UIKit.h>
#include <execinfo.h>
//#import <CrashReporter/CrashReporter.h>

NSString * const kSYQSignalExceptionName = @"kSignalExceptionName";
NSString * const kSYQSignalKey = @"kSignalKey";
NSString * const kSYQCaughtExceptionStackInfoKey = @"kCaughtExceptionStackInfoKey";



@interface SYQCatchExceptionManager ()<UIAlertViewDelegate>
@property (nonatomic, assign) BOOL ignore;

@end


@implementation SYQCatchExceptionManager

+ (instancetype)shareInstance {
    static SYQCatchExceptionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SYQCatchExceptionManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setCatchExceptionHandler];
    }
    return self;
}

- (void)setCatchExceptionHandler {
    // 1.捕获一些异常导致的崩溃
    NSSetUncaughtExceptionHandler(&UnCaughtExceptionHandlers);
    
    // 2.捕获非异常情况，通过signal传递出来的崩溃
    signal(SIGABRT, SignalExceptionHandler);
    signal(SIGILL, SignalExceptionHandler);
    signal(SIGSEGV, SignalExceptionHandler);
    signal(SIGFPE, SignalExceptionHandler);
    signal(SIGBUS, SignalExceptionHandler);
    signal(SIGPIPE, SignalExceptionHandler);
    
}
void UnCaughtExceptionHandlers(NSException *exception) {
    NSLog(@"捕获到当前异常");
    // 获取异常的堆栈信息
    NSArray *callStack = [exception callStackSymbols];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:callStack forKey:kSYQCaughtExceptionStackInfoKey];
    
    // 将当前堆栈信息进行相应封装m，可以上传到服务器
    NSException *customException = [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo];
    [[SYQCatchExceptionManager shareInstance] performSelectorOnMainThread:@selector(mySelfHandleException:) withObject:customException waitUntilDone:YES];

}

void SignalExceptionHandler(int signal){
    NSArray *callStack = [SYQCatchExceptionManager backtrace];
    NSLog(@"信号捕获崩溃，堆栈信息：%@",callStack);
    NSString *name = kSYQSignalExceptionName;
    NSString *reson = [NSString stringWithFormat:@"signal %d was raised",signal];
    NSDictionary *dict = @{kSYQSignalKey:@(signal)};
    NSException *customException = [NSException exceptionWithName:name reason:reson userInfo:dict];
    [[SYQCatchExceptionManager shareInstance] performSelectorOnMainThread:@selector(mySelfHandleException:) withObject:customException waitUntilDone:YES];
}

+ (NSArray *)backtrace
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);

    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (int i = 0; i < frames; i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);

    return backtrace;
}



- (void)mySelfHandleException:(NSException *)exception {
    NSString *message = [NSString stringWithFormat:@"崩溃原因如下:\n%@\n%@",
                         [exception reason],
                         [[exception userInfo] objectForKey:kSYQCaughtExceptionStackInfoKey]];
    NSLog(@"%@",message);
    
    [self showAlertWithException:exception];
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    while (!self.ignore) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    
// 通过signal传递出来的崩溃 的处理方法
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);

    if ([[exception name] isEqual:kSYQSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:kSYQSignalKey] intValue]);
    } else {
        [exception raise];
    }
}


- (void)showAlertWithException:(NSException *)exception{

    UIWindow* window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                window = windowScene.windows.firstObject;
                break;
            }
        }
    }else{
        window = [UIApplication sharedApplication].keyWindow;
    }
    
    UIViewController *vc = window.rootViewController;
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"系统捕获到了某些异常，即将退出应用或者帮助我们上传错误信息" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertVc addAction:[UIAlertAction actionWithTitle:@"发送异常信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"发送或者异常数据");
        //发送异常信息到服务器或者保存到本地下次发送
    }]];
    [alertVc addAction:[UIAlertAction actionWithTitle:@"退出应用" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"退出应用");
        self.ignore = YES;
    }]];
    [vc presentViewController:alertVc animated:YES completion:nil];
}


@end
