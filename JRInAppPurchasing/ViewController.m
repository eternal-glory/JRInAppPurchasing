//
//  ViewController.m
//  JRInAppPurchasing
//
//  Created by literature on 2020/11/20.
//

#import "ViewController.h"
#import "JRInAppPurchasing.h"

#import "MBProgressHUD.h"

@interface ViewController () <JRInAppPurchasingDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _InAppPurchasing.delegate = self;
}

- (void)wh_updatedTransactions:(JRPaymentTransactionState)state {
    if (state == JRPaymentTransactionStateFinished) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }
}

- (IBAction)action:(id)sender {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_InAppPurchasing identifyCanMakePaymentWithProductId:@"zhidianshop6"];
}

@end
