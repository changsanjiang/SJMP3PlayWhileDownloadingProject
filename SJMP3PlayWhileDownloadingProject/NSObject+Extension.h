//
//  NSObject+Extension.h
//  2016年11月16日21:39:19
//
//  Created by ya on 16/11/22.
//  Copyright © 2016年 ya. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Extension)

 // MARK: -  获取类信息
@property (nonatomic, strong, class, readonly) NSArray<NSString *> *csj_invarList;
@property (nonatomic, strong, class, readonly) NSArray<NSString *> *csj_methodList;
@property (nonatomic, strong, class, readonly) NSArray<NSString *> *csj_propertyList;
@property (nonatomic, strong, class, readonly) NSArray<NSString *> *csj_protocolList;
@property (nonatomic, strong, class, readonly) NSArray<NSString *> *csj_invarTypeList;

 // MARK: -  检查对象是否为空.
@property (nonatomic, copy, class, readonly) NSObject *(^checkObj)(id);

 // MARK: -  返回一个Window
+ (instancetype)csj_windowWithRootViewController:(UIViewController *)viewController;

 // MARK: -  VFL简单约束
NSArray<__kindof NSLayoutConstraint *> *csj_constraints(UIView *target,
                                                        NSArray<NSString *> *formats,
                                                        NSDictionary<NSString *, UIView *> *views);

 // MARK: -  发送通知
extern void NotificationCenterPost(NSString         *key,
                                   id              _Nullable obj,
                                   NSDictionary     * _Nullable userInfo);
 // MARK: -  接受通知
extern void NotificationCenterAddObserver(id        observer,
                                          NSString  *key,
                                          SEL       sel);
 // MARK: -  移除通知
extern void NotificationRemoveObserver(id self);

 // MARK: -  目录相关
extern NSString *           DocumentDirectory();
extern NSString *           CachesDirectory();
extern NSString *           TemporaryDirectory();
extern NSString *           BundleName();
extern NSString *           NSStringFromInteger(NSInteger integer);
extern UIImage  *           Image(NSString *imageName);

 // MARK: -  nib相关
extern __kindof UIView *    nibView(NSString *nibName, id self);
extern UINib *              nib(NSString *nibName);

 // MARK: -  storyboard相关
extern __kindof UIViewController * storyboardViewController(NSString *sbName,
                                                            NSString *id);
extern UIStoryboard *              storyboard(NSString *sbName);


extern void netWorkingStateAlert(NSString *title, NSString *msg, BOOL *netSwitch, UIViewController *presentingVC);

 /// 获取当前设备可用内存(单位：MB）
extern double availableMemory();

 /// 获取当前任务所占用的内存（单位：MB）
extern double usedMemory();

extern BOOL sjSaveImage(UIImage *image, NSString *savePath);

@end

NS_ASSUME_NONNULL_END
