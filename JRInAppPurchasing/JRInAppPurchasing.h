//
//  JRInAppPurchasing.h
//  JRInAppPurchasing
//
//  Created by literature on 2020/11/20.
//

#import <Foundation/Foundation.h>

#define kServiceStatus  0

#if kServiceStatus == 0

#define ITMS_VERIFY_RECEIPT_URL @"https://sandbox.itunes.apple.com/verifyReceipt"

#elif kServiceStatus == 1

#define ITMS_VERIFY_RECEIPT_URL @"http://192.168.1.151:8028/api/pay/verify_apple_order"

#endif

#define _InAppPurchasing [JRInAppPurchasing sharedInstance]

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, JRPaymentTransactionState) {
    /// 没有Payment权限
    JRPaymentTransactionStateNoPaymentPermission,
    /// addPayment失败
    JRPaymentTransactionStateAddPaymentFailed,
    /// 正在购买
    JRPaymentTransactionStatePurchasing,
    /// 购买完成
    JRPaymentTransactionStatePurchased,
    /// 用户取消
    JRPaymentTransactionStateCancel,
    /// 恢复购买
    JRPaymentTransactionStateRestored,
    /// 订单效验成功
    JRPaymentTransactionStateValidationSuccess,
    /// 订单效验失败
    JRPaymentTransactionStateValidationFailed,
    /// 购买失败
    JRPaymentTransactionStateFailed,
    /// 最终状态未确定
    JRPaymentTransactionStateDeferred,
    /// 交易结束
    JRPaymentTransactionStateFinished
};

@protocol JRInAppPurchasingDelegate <NSObject>

@required
- (void)wh_updatedTransactions:(JRPaymentTransactionState)state;

@end

@interface JRInAppPurchasing : NSObject

@property (class, nonatomic, strong, readonly) JRInAppPurchasing *sharedInstance;

@property (nonatomic, weak) id<JRInAppPurchasingDelegate> delegate;

- (void)identifyCanMakePaymentWithProductId:(NSString *)productId;

@end

NS_ASSUME_NONNULL_END
