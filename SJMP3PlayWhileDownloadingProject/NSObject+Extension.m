//
//  NSObject+Extension.m
//  2016年11月16日21:39:19
//
//  Created by ya on 16/11/22.
//  Copyright © 2016年 ya. All rights reserved.
//

#import "NSObject+Extension.h"
#import <objc/runtime.h>

// 获取当前设备可用内存及所占内存的头文件
#import <sys/sysctl.h>
#import <mach/mach.h>

@implementation NSObject (Extension)

@dynamic checkObj;

+ (instancetype)csj_windowWithRootViewController:(UIViewController *)viewController {
    return ({
        if ( ![viewController isKindOfClass:[UIViewController class]] ) {
            NSLog(@"参数无效, %zd", __LINE__);
            return nil;
        }
        UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        window.backgroundColor = [UIColor whiteColor];
        window.rootViewController = viewController;
        [window makeKeyAndVisible];
        window;
    });
}


NSArray<__kindof NSLayoutConstraint *> *csj_constraints(UIView *target,
                                                        NSArray<NSString *> *formats,
                                                        NSDictionary<NSString *, UIView *> *views) {

    target.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableArray<NSLayoutConstraint *> *constraintsArrayM = [[NSMutableArray alloc] init];

    for (NSString *format in formats) {
        [constraintsArrayM addObjectsFromArray:({
            [NSLayoutConstraint constraintsWithVisualFormat:format
                                                    options:0
                                                    metrics:nil
                                                      views:views];
        })];
    }

    return constraintsArrayM;
}



+ (NSArray<NSString *> *)csj_propertyList {

    NSMutableArray <NSString *> *namesArrM = [NSMutableArray array];
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(self, &outCount);

    if (propertyList != NULL && outCount > 0) {
        for (int i = 0; i < outCount; i ++) {
            objc_property_t property = propertyList[i];
            const char *name  = property_getName(property);
            NSString *nameStr = [NSString stringWithUTF8String:name];
            [namesArrM addObject:nameStr];
        }
    }

    free(propertyList);
    return namesArrM.copy;
}

+ (NSArray<NSString *> *)csj_methodList; {

    NSMutableArray *methodNamesArrM = [NSMutableArray array];
    unsigned int outCount = 0;
    Method *methodList = class_copyMethodList(self, &outCount);

    if (methodList != NULL && outCount > 0) {
        for (int i = 0; i < outCount; i ++) {
            SEL sel = method_getName(methodList[i]);
            NSString *methodName = NSStringFromSelector(sel);
            [methodNamesArrM addObject:methodName];
        }
    }
    free(methodList);
    return methodNamesArrM.copy;
}


+ (NSArray<NSString *> *)csj_protocolList {
    NSMutableArray *protocolNamesArrM = [NSMutableArray array];

    unsigned int outCount = 0;
    Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(self, &outCount);
    if (protocolList != NULL && outCount > 0) {
        for (int i = 0; i < outCount; i ++) {
            NSString *protocolName = NSStringFromProtocol(protocolList[i]);
            [protocolNamesArrM addObject:protocolName];
        }
    }

    free(protocolList);
    return protocolNamesArrM.copy;
}

+ (NSArray<NSString *> *)csj_invarList {

    NSMutableArray *invarListArrM = [NSMutableArray array];

    unsigned int outCount = 0;
    Ivar *ivarList = class_copyIvarList(self, &outCount);
    if (ivarList != NULL && outCount > 0) {
        for (int i = 0; i < outCount; i ++) {
            const char *name = ivar_getName(ivarList[i]);
            NSString *nameStr = [NSString stringWithUTF8String:name];
            [invarListArrM addObject:nameStr];
        }
    }
    free(ivarList);
    return invarListArrM.copy;
}

+ (NSArray<NSString *> *)csj_invarTypeList {
    
    unsigned int ivarCount = 0;
    
    struct objc_ivar **ivarList = class_copyIvarList(self, &ivarCount);
    
    NSMutableArray<NSString *> *listM = [NSMutableArray new];
    
    // 遍历获取类的属性类型
    for ( int i = 0 ; i < ivarCount ; i ++ ) {
        const char *cType = ivar_getTypeEncoding(ivarList[i]);
        [listM addObject:[NSString stringWithUTF8String:cType]];
    }

    free(ivarList);
    return listM;
}

/// 方法转调用.
//NSInvocation* sj_getMethodInvocationFunc(id target, SEL _cmd, ...) {
//
//    NSMethodSignature *methodSignature = [target methodSignatureForSelector:_cmd];
//    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
//
//    va_list arguments;
//    va_start(arguments, _cmd);
//    NSUInteger count = methodSignature.numberOfArguments;
//    for (int index = 2; index < count ; index ++) { /// 为什么是从2开始, 因为target, _cmd, 已经占坑了, 真实的参数从索引2开始.
//        void *parameter = va_arg(arguments, void *);
//        [invocation setArgument:&parameter atIndex:index];
//    }
//    va_end(arguments);
//
//    invocation.target   = target;
//    invocation.selector = _cmd;
//    return invocation;
//}

extern void NotificationCenterPost(NSString *key,
                                   id obj,
                                   NSDictionary *userInfo) {
    [[NSNotificationCenter defaultCenter] postNotificationName:key
                                                        object:obj
                                                      userInfo:userInfo];
}

extern void NotificationCenterAddObserver(id observer,
                                          NSString *key,
                                          SEL sel) {
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:sel
                                                 name:key
                                                object:nil];
}

extern void NotificationRemoveObserver(id self) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


extern NSString * DocumentDirectory() {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
}

extern NSString * CachesDirectory() {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

extern NSString * TemporaryDirectory() {
    return NSTemporaryDirectory();
}

extern NSString * BundleName() {
    return [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
}


extern NSString * NSStringFromInteger(NSInteger integer) {
    return [NSString stringWithFormat:@"%zd", integer];
}

extern UIImage  * Image(NSString *name) {
    return [UIImage imageNamed:name];
}


extern __kindof UIView *nibView(NSString *nibName, id self) {
    return [[UINib nibWithNibName:nibName bundle:nil] instantiateWithOwner:self
                                                                   options:nil].lastObject;
}

extern UINib *nib(NSString *nibName) {
    return [UINib nibWithNibName:nibName bundle:nil];
}

extern __kindof UIViewController * storyboardViewController(NSString *sbName, NSString *id) {
    return [storyboard(sbName) instantiateViewControllerWithIdentifier:id];
}

extern UIStoryboard *              storyboard(NSString *sbName) {
    return [UIStoryboard storyboardWithName:sbName bundle:nil];
}

- (NSObject *(^)(id))checkObj {
    static NSInteger index = 0;
    return ^NSObject *(id obj) {
        index ++;
        if (obj == nil) {
            NSLog(@"第%zd个为空!", index);
        }
        return @"";
    };
}

extern void netWorkingStateAlert(NSString *title, NSString *msg, BOOL *netSwitch, UIViewController *presentingVC) {

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    /// 好
    UIAlertAction *okAction =
    [UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        *netSwitch = YES;
        
    }];
    
    [alertController addAction:okAction];
    
    
    /// 取消
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        *netSwitch = NO;
    }];
    
    [alertController addAction:cancelAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [presentingVC presentViewController:alertController animated:YES completion:nil];
    });
}

// MARK: Other

// 获取当前设备可用内存(单位：MB）
extern double availableMemory() {
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    
    return ((vm_page_size *vmStats.free_count) / 1024.0) / 1024.0;
}

// 获取当前任务所占用的内存（单位：MB）
extern double usedMemory() {
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO,
                                         (task_info_t)&taskInfo,
                                         &infoCount);
    
    if (kernReturn != KERN_SUCCESS
        ) {
        return NSNotFound;
    }
    
    return taskInfo.resident_size / 1024.0 / 1024.0;
}


BOOL sjSaveImage(UIImage *image, NSString *savePath) {
    // 缩放保存
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
    // 将图片写入文件
    return [imageData writeToFile:savePath atomically:YES];
}

@end


 // MARK: -----------------------<-测试->-----------------------

#if 0
#pragma mark -

float f2 = 3.01;

/// 天花板, 返回整数, 有小数就进一位.
NSLog(@"%lf", ceil(f2));  /// 4.000000

/// 地板, 返回整数, 丢掉小数位.
NSLog(@"%lf", floor(f2)); /// 3.000000



// MARK:- 混合使用ARC 和 非ARC

/// 如果项目使用的 非ARC 模式,则为ARC模式的代码文件加入 -fobjc-arc标签.
/// 如果项目使用的 ARC 模式, 则为 非ARC 模式的代码文件加入 - fno-objc-arc  标签.
/// 添加标签的方法:
/// 1. 打开: Target -> Build Phases -> Complie Sources
/// 2. 双击对应的 .m 文件
/// 3. 在弹出窗口中输入上面的标签. -fobjc-arc / -fno-objc-arc
/// 4. 点击 done 保存


// MARK:- 关闭\收起键盘方法总结

/// 点击 return 按钮,收起键盘
- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    return [textField resignFirstResponder];
}

/// 点击背景View收起键盘(你的View必须是继承与UIControl)
- (void)clickBackgroundView {
    [self endEditing:YES];
}

/// 可以在任何地方加上这句话, 可以用来统一收起键盘
- (void)test {

    [[[UIApplication sharedApplication] keyWindow] endEditing:YES];
}

// MARK:- link

/**
 -all_load   就是会加载静态库文件中的所有成员
 -ObjC       就是会加载静态库文件中实现一个类或者分类的所有成员
 -force_load (包的路径) 就是会加载指定路径的静态库文件中的所有成员
 所以对于使用 runtime 时候的反射调用的方法应该使用这三个中的一个进行 link, 以保证所有的类都可以加载到内存中供程序动态调用.
 */

// MARK: -Block

struct Block_layout {
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 *descriptor;
    // imported variables
};

block;
............
void *pBlock = (__bridge void *)block;
void (*invoke)(void *, ...) = *((void **))pBlock + 2);
invoke(pBlock);


#endif


