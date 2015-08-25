//
//  LDSDKManager.m
//  TestThirdPlatform
//
//  Created by ss on 15/8/14.
//  Copyright (c) 2015年 Lede. All rights reserved.
//

#import "LDSDKManager.h"
#import "LDSDKRegisterService.h"
#import "LDSDKPayService.h"
#import "LDSDKAuthService.h"
#import "LDSDKShareService.h"

NSString *const LDSDKConfigAppIdKey = @"kAppID";
NSString *const LDSDKConfigAppSecretKey = @"kAppSecret";
NSString *const LDSDKConfigAppSchemeKey = @"kAppScheme";
NSString *const LDSDKConfigAppPlatformTypeKey = @"kAppPlatformType";
NSString *const LDSDKConfigAppDescriptionKey   = @"kAppDescription";

NSString *const LDSDKShareContentTitleKey       = @"title";
NSString *const LDSDKShareContentDescriptionKey = @"description";
NSString *const LDSDKShareContentImageUrlKey    = @"imageurl";
NSString *const LDSDKShareContentWapUrlKey      = @"webpageurl";
NSString *const LDSDKShareContentTextKey      = @"text";


//SDKManager管理的功能服务类型
typedef NS_ENUM(NSUInteger, LDSDKServiceType)
{
    LDSDKServiceRegister = 1,  //sdk应用注册服务
    LDSDKServicePay,           //sdk支付服务
    LDSDKServiceShare,         //sdk分享服务
    LDSDKServiceOAuth          //sdk第三方登录服务
};


static NSArray *sdkServiceConfigList = nil;

@implementation LDSDKManager

#pragma mark -
#pragma mark - SDK Register Interface

/**
 *  是否安装客户端
 *
 *  @param type  安装类型，整数值
 *
 *  @return YES则已安装
 */
+ (BOOL)isSDKPlatformAppInstalled:(LDSDKPlatformType)platformType
{
    Class registerServiceImplCls = [self getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceRegister];
    if(registerServiceImplCls != nil){
        return [[registerServiceImplCls sharedService] platformInstalled];
    } else {
        if (platformType == LDSDKPlatformAliPay) {
            return YES;
        } else {
            return NO;
        }
    }
}

+ (BOOL)isRegisteredOnPlatform:(LDSDKPlatformType)platformType
{
    Class registerServiceImplCls = [self getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceRegister];
    if (registerServiceImplCls != nil) {
        return [LDSDKManager isSDKPlatformAppInstalled:platformType] && [[registerServiceImplCls sharedService] isRegistered];
    }
    return NO;
}

/**
 *  根据配置列表依次注册第三方SDK
 *
 *  @return YES则配置成功
 */
+ (void)registerWithPlatformConfigList:(NSArray *)configList;
{
    if(configList == nil || configList.count == 0) return;
    
    for(NSDictionary *onePlatformConfig in configList){
        LDSDKPlatformType platformType = [onePlatformConfig[LDSDKConfigAppPlatformTypeKey] intValue];
        Class registerServiceImplCls = [self getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceRegister];
        if(registerServiceImplCls != nil){
            [[registerServiceImplCls sharedService] registerWithPlatformConfig:onePlatformConfig];
        }
    }
}


#pragma mark -
#pragma mark - SDK Pay Interface

/**
 *  支付
 *
 *  @param payType     支付类型，支付宝或微信
 *  @param orderString 签名后的订单信息字符串
 *  @param callback    回调
 */
+ (void)payOrderWithType:(LDSDKPlatformType)payType orderString:(NSString *)orderString callback:(LDSDKPayCallback)callback
{
    Class payServiceImplCls = [LDSDKManager getServiceProviderWithPlatformType:payType serviceType:LDSDKServicePay];
    if(payServiceImplCls != nil){
        [[payServiceImplCls sharedService] payOrderString:orderString callback:callback];
    } else {
        if (callback) {
            NSError *errorTmp = [NSError errorWithDomain:@"pay" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"该模块可能未导入或不支持支付功能", @"NSLocalizedDescription", nil]];
            callback(nil, errorTmp);
            return;
        }
    }
}

/**
 *  支付完成后结果的处理
 *
 *  @param result   支付结果
 *  @param callback 支付宝负责的回调
 */
+ (BOOL)handlePayType:(LDSDKPlatformType)payType resultURL:(NSURL *)result callback:(void (^)(NSDictionary *))callback
{
    Class payServiceImplCls = [LDSDKManager getServiceProviderWithPlatformType:payType serviceType:LDSDKServicePay];
    if(payServiceImplCls != nil){
        return [[payServiceImplCls sharedService] payProcessOrderWithPaymentResult:result standbyCallback:callback];
    }
    return NO;
}


#pragma mark -
#pragma mark - SDK Share Interface

+ (NSArray *)availableSharePlatformList
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if ([LDSDKManager isRegisteredOnPlatform:LDSDKPlatformQQ]) {
        [result addObject:[NSNumber numberWithUnsignedInteger:LDSDKPlatformQQ]];
    }
    
    if ([LDSDKManager isRegisteredOnPlatform:LDSDKPlatformWeChat]) {
        [result addObject:[NSNumber numberWithUnsignedInteger:LDSDKPlatformWeChat]];
    }
    
    if ([LDSDKManager isRegisteredOnPlatform:LDSDKPlatformYiXin]) {
        [result addObject:[NSNumber numberWithUnsignedInteger:LDSDKPlatformYiXin]];
    }
    
    return [NSArray arrayWithArray:result];
}

+ (BOOL)isAvailableShareToPlatform:(LDSDKPlatformType)platformType;
{
    return [LDSDKManager isRegisteredOnPlatform:platformType];
}


+ (void)shareToPlatform:(LDSDKPlatformType)platformType
            shareModule:(LDSDKShareToModule)shareModule
               withDict:(NSDictionary *)dict
             onComplete:(LDSDKShareCallback)complete{
    Class shareServiceImplCls = [[self class] getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceShare];
    if(shareServiceImplCls != nil){
        [[shareServiceImplCls sharedService] shareWithContent:dict shareModule:shareModule onComplete:complete];
    } else {
        if(complete){
            NSError *errorTmp = [NSError errorWithDomain:@"SDK分享组件" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"请先导入分享平台的SDK", @"NSLocalizedDescription", nil]];
            complete(NO, errorTmp);
        }
    }
}

#pragma mark -
#pragma mark - SDK Login Interface

+ (BOOL)isLoginEnabledOnPlatform:(LDSDKPlatformType)platformType
{
    Class loginServiceImplCls = [LDSDKManager getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceOAuth];
    if(loginServiceImplCls != nil){
        return [[loginServiceImplCls sharedService] platformLoginEnabled];
    }
    return NO;
}

+ (void)loginToPlatform:(LDSDKPlatformType)platformType withCallback:(LDSDKLoginCallback)callback
{
    Class loginServiceImplCls = [LDSDKManager getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceOAuth];
    if(loginServiceImplCls != nil){
        [[loginServiceImplCls sharedService] platformLoginWithCallback:callback];
    }
}

+ (void)logoutFromPlatform:(LDSDKPlatformType)platformType
{
    Class loginServiceImplCls = [LDSDKManager getServiceProviderWithPlatformType:platformType serviceType:LDSDKServiceOAuth];
    if(loginServiceImplCls != nil){
        [[loginServiceImplCls sharedService] platformLogout];
    }
}

#pragma mark -
#pragma mark - SDK Callback Interface

/**
 *  处理url返回
 *
 *  @param url       第三方应用的url回调
 *
 *  @return YES则处理成功
 */
+ (BOOL)handleOpenURL:(NSURL *)url
{
    if ([LDSDKManager handlePayType:LDSDKPlatformWeChat resultURL:url callback:NULL]) {
        return YES;
    }

    if([LDSDKManager handleOpenURL:url withType:LDSDKPlatformQQ] ||
       [LDSDKManager handleOpenURL:url withType:LDSDKPlatformWeChat] ||
       [LDSDKManager handleOpenURL:url withType:LDSDKPlatformYiXin]) {
        return YES;
    }
    if ([LDSDKManager handlePayType:LDSDKPlatformAliPay resultURL:url callback:NULL]) {
        return YES;
    }

    return YES;
}

+ (BOOL)handleOpenURL:(NSURL *)url withType:(LDSDKPlatformType)type
{
    Class registerServiceImplCls = [self getServiceProviderWithPlatformType:type serviceType:LDSDKServiceRegister];
    if(registerServiceImplCls != nil){
        return [[registerServiceImplCls sharedService] handleResultUrl:url];
    }
    return NO;
}


#pragma mark - 
#pragma mark - Common Method

/**
 * 根据平台类型和服务类型获取服务提供者
 */
+(Class)getServiceProviderWithPlatformType:(LDSDKPlatformType)platformType serviceType:(LDSDKServiceType)serviceType{
    if(sdkServiceConfigList == nil){
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"SDKServiceConfig" ofType:@"plist"];
        sdkServiceConfigList = [[NSArray alloc] initWithContentsOfFile:plistPath];
    }

    Class serviceProvider = nil;
    for(NSDictionary *oneSDKServiceConfig in sdkServiceConfigList){
        //find the specified platform
        if([oneSDKServiceConfig[@"platformType"] intValue] == platformType){
            NSArray *supportTypes = oneSDKServiceConfig[@"supportType"];
            if(supportTypes != nil && supportTypes.count > 0){
                for(NSNumber *supportService in supportTypes){
                    //find the specified service
                    if([supportService intValue] == serviceType){
                        serviceProvider = NSClassFromString(oneSDKServiceConfig[@"serviceProvider"]);
                        break;
                    }
                }//for
            }
            break;
        }//if
    }//for

    return serviceProvider;
}



@end
