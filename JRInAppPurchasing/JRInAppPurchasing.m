//
//  JRInAppPurchasing.m
//  JRInAppPurchasing
//
//  Created by literature on 2020/11/20.
//

#import "JRInAppPurchasing.h"
#import <StoreKit/StoreKit.h>

static JRInAppPurchasing *_instance = nil;

@interface JRInAppPurchasing () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, strong) SKProductsRequest *request;

@property (nonatomic, strong) NSString *productId;

@end

@implementation JRInAppPurchasing

+ (JRInAppPurchasing *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[JRInAppPurchasing alloc] init];
    });
    return _instance;
}

- (void)identifyCanMakePaymentWithProductId:(NSString *)productId {
    if (productId.length == 0) {
        [self wh_handleActionWithState:JRPaymentTransactionStateAddPaymentFailed];
        return;
    }
    if ([SKPaymentQueue canMakePayments]) {
        self.productId = productId;
        [self releaseRequest];
        NSSet *indentifiers = [NSSet setWithArray:@[productId]];
        self.request = [[SKProductsRequest alloc] initWithProductIdentifiers:indentifiers];
        self.request.delegate = self;
        [self.request start];
    } else {
        [self wh_handleActionWithState:JRPaymentTransactionStateNoPaymentPermission];
    }
}

#pragma mark - - - - SKProductsRequestDelegate - - - -
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"-----------收到产品反馈信息-------------- 产品ID:%@ 产品数量:%ld",response.invalidProductIdentifiers, (long)response.products.count);
    
    SKProduct *productModel = nil;
    for (SKProduct *product in response.products) {
        if ([product.productIdentifier isEqualToString:self.productId]) {
            productModel = product;
            break;
        }
    }
    
#if DEBUG
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu",(unsigned long)response.products.count);
    NSLog(@"SKProduct 描述信息%@", productModel.description);
    NSLog(@"产品标题 %@", productModel.localizedTitle);
    NSLog(@"产品描述信息: %@" , productModel.localizedDescription);
    NSLog(@"价格: %@", productModel.price);
    NSLog(@"Product id: %@" , productModel.productIdentifier);
    NSLog(@"发送购买请求");
#endif
    
    if (productModel) {
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:productModel];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"------------------请求失败-----------------:%@", error);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"------------反馈信息结束-----------------");
}

#pragma mark - - - - SKPaymentTransactionObserver - - - -
- (void)paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        JRPaymentTransactionState state;
        switch(transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing: {
                // 连接appStore
                state = JRPaymentTransactionStatePurchasing;
                break;
            }
            case SKPaymentTransactionStatePurchased: {
                state = JRPaymentTransactionStatePurchased;
                //交易完成
                [self completeTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateFailed: {
                //交易失败
                if (transaction.error.code!= SKErrorPaymentCancelled) {
                    state = JRPaymentTransactionStateFailed;
                } else {
                    state = JRPaymentTransactionStateCancel;
                }
                [self finshTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateRestored: {
                // 已经购买过该商品
                state = JRPaymentTransactionStateRestored;
#if DEBUG
                NSLog(@"已经购买过商品");
#endif
                [self finshTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateDeferred: {
                state = JRPaymentTransactionStateDeferred;
                break;
            }
            default:
                break;
        }
        [self wh_handleActionWithState:state];
    }
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue*)queue removedTransactions:(NSArray *)transactions {
    
    NSLog(@"---removedTransactions");
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue*)queue restoreCompletedTransactionsFailedWithError:(NSError*)error {
    NSLog(@"restoreCompletedTransactionsFailedWithError");
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue*)queue {
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
}

// Sent when the download state has changed.
- (void)paymentQueue:(SKPaymentQueue*)queue updatedDownloads:(NSArray *)downloads {
    NSLog(@"updatedDownloads");
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    [self verifyPurchaseWithPaymentTransaction:transaction];
}

- (void)finshTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"结束交易");
    // 结束交易
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    [self wh_handleActionWithState:JRPaymentTransactionStateFinished];
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction {
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    NSString *receiptString = [receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];// 转化为base64字符串
    
    // 交易凭证为空验证失败
    if (!receiptString) {
        [self wh_handleActionWithState:JRPaymentTransactionStateValidationFailed];
        return;
    }
    
    NSError *error;
    NSDictionary *requestContents = [NSDictionary dictionary];
    if (kServiceStatus == 0) {
        requestContents = @{ @"receipt-data": receiptString };
    } else {
        requestContents = @{ @"receipt": receiptString };
    }
    
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
    NSURL *storeURL = [NSURL URLWithString:ITMS_VERIFY_RECEIPT_URL];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    [storeRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:storeRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            // 无法连接服务器,购买校验失败
            [self wh_handleActionWithState:JRPaymentTransactionStateValidationFailed];
        } else {
            NSError *err;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (!jsonResponse) {
                // 苹果服务器校验数据返回为空校验失败
                [self wh_handleActionWithState:JRPaymentTransactionStateValidationFailed];
            }
            // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
            NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
            if (status && [status isEqualToString:@"21007"]) {
                
            } else if (status && [status isEqualToString:@"0"]) {
                [self wh_handleActionWithState:JRPaymentTransactionStateValidationSuccess];
            }
#if DEBUG
            NSLog(@"----验证结果 %@",jsonResponse);
#endif
        }
        // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
        [self finshTransaction:transaction];
    }];
    [task resume];
}

- (void)wh_handleActionWithState:(JRPaymentTransactionState)state {
    if (state == JRPaymentTransactionStateNoPaymentPermission) {
        NSLog(@"不允许程序内付费");
    } else if (state == JRPaymentTransactionStateAddPaymentFailed) {
        NSLog(@"添加Payment失败");
    } else if (state == JRPaymentTransactionStatePurchasing) {
        NSLog(@"正在购买");
    } else if (state == JRPaymentTransactionStatePurchased) {
        NSLog(@"购买完成");
    } else if (state == JRPaymentTransactionStateCancel) {
        NSLog(@"用户取消");
    } else if (state == JRPaymentTransactionStateRestored) {
        NSLog(@"恢复购买");
    } else if (state == JRPaymentTransactionStateFailed) {
        NSLog(@"购买失败");
    } else if (state == JRPaymentTransactionStateValidationSuccess) {
        NSLog(@"订单效验成功");
    } else if (state == JRPaymentTransactionStateValidationFailed) {
        NSLog(@"订单效验失败");
    } else {
        NSLog(@"最终状态未确定");
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(wh_updatedTransactions:)]) {
            [self.delegate wh_updatedTransactions:state];
        }
    });
}

- (instancetype)init {
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [self releaseRequest];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)releaseRequest {
    if (self.request) {
        [self.request cancel];
        self.request.delegate = nil;
        self.request = nil;
    }
}

@end
