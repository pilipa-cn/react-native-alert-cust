/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */


#import "PLPAlertManager.h"

#import <React/RCTAssert.h>
#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import "UIColor+Tool.h"


@implementation RCTConvert (UIAlertViewStyle)

RCT_ENUM_CONVERTER(RCTAlertViewStyle, (@{
                                         @"default": @(RCTAlertViewStyleDefault),
                                         @"secure-text": @(RCTAlertViewStyleSecureTextInput),
                                         @"plain-text": @(RCTAlertViewStylePlainTextInput),
                                         @"login-password": @(RCTAlertViewStyleLoginAndPasswordInput),
                                         }), RCTAlertViewStyleDefault, integerValue)

@end

@interface PLPAlertManager()

@end

@implementation PLPAlertManager
{
    NSHashTable *_alertControllers;
}

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (void)invalidate
{
    for (UIAlertController *alertController in _alertControllers) {
        [alertController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

/**
 * @param {NSDictionary} args Dictionary of the form
 *
 *   @{
 *     @"message": @"<Alert message>",
 *     @"buttons": @[
 *       @{@"<key1>": @"<title1>"},
 *       @{@"<key2>": @"<title2>"},
 *     ],
 *     @"cancelButtonKey": @"<key2>",
 *   }
 * The key from the `buttons` dictionary is passed back in the callback on click.
 * Buttons are displayed in the order they are specified.
 */
RCT_EXPORT_METHOD(alertWithArgs:(NSDictionary *)args
                  callback:(RCTResponseSenderBlock)callback)
{
    NSString *title = [RCTConvert NSString:args[@"title"]];
    NSString *message = [RCTConvert NSString:args[@"message"]];
    RCTAlertViewStyle type = [RCTConvert RCTAlertViewStyle:args[@"type"]];
    NSArray<NSDictionary *> *buttons = [RCTConvert NSDictionaryArray:args[@"buttons"]];
    NSString *defaultValue = [RCTConvert NSString:args[@"defaultValue"]];
    NSString *cancelButtonKey = [RCTConvert NSString:args[@"cancelButtonKey"]];
    NSString *destructiveButtonKey = [RCTConvert NSString:args[@"destructiveButtonKey"]];
    UIKeyboardType keyboardType = [RCTConvert UIKeyboardType:args[@"keyboardType"]];
    if (!title && !message) {
        RCTLogError(@"Must specify either an alert title, or message, or both");
        return;
    }
    
    if (buttons.count == 0) {
        if (type == RCTAlertViewStyleDefault) {
            buttons = @[@{@"0": RCTUIKitLocalizedString(@"OK")}];
            cancelButtonKey = @"0";
        } else {
            buttons = @[
                        @{@"0": RCTUIKitLocalizedString(@"OK")},
                        @{@"1": RCTUIKitLocalizedString(@"Cancel")},
                        ];
            cancelButtonKey = @"1";
        }
    }
    
    UIViewController *presentingController = RCTPresentedViewController();
    if (presentingController == nil) {
        RCTLogError(@"Tried to display alert view but there is no application window. args: %@", args);
        return;
    }
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:title
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleAlert];
    switch (type) {
        case RCTAlertViewStylePlainTextInput: {
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.secureTextEntry = NO;
                textField.text = defaultValue;
                textField.keyboardType = keyboardType;
            }];
            break;
        }
        case RCTAlertViewStyleSecureTextInput: {
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = RCTUIKitLocalizedString(@"Password");
                textField.secureTextEntry = YES;
                textField.text = defaultValue;
                textField.keyboardType = keyboardType;
            }];
            break;
        }
        case RCTAlertViewStyleLoginAndPasswordInput: {
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = RCTUIKitLocalizedString(@"Login");
                textField.text = defaultValue;
                textField.keyboardType = keyboardType;
            }];
            [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = RCTUIKitLocalizedString(@"Password");
                textField.secureTextEntry = YES;
            }];
            break;
        }
        case RCTAlertViewStyleDefault:
            break;
    }
    
    alertController.message = message;
    
    for (NSDictionary<NSString *, id> *button in buttons) {
        if (button.count != 1) {
            RCTLogError(@"Button definitions should have exactly one key.");
        }
        NSString *buttonKey = button.allKeys.firstObject;
        
        NSDictionary *buttonDic = [RCTConvert NSDictionary:button[buttonKey]];
        
        NSString *buttonTitle = buttonDic[@"0"];
        
        
        
        
        UIAlertActionStyle buttonStyle = UIAlertActionStyleDefault;
        if ([buttonKey isEqualToString:cancelButtonKey]) {
            buttonStyle = UIAlertActionStyleCancel;
        } else if ([buttonKey isEqualToString:destructiveButtonKey]) {
            buttonStyle = UIAlertActionStyleDestructive;
        }
        __weak UIAlertController *weakAlertController = alertController;
        
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:buttonTitle
                                                              style:buttonStyle
                                                            handler:^(__unused UIAlertAction *action) {
                                                                switch (type) {
                                                                    case RCTAlertViewStylePlainTextInput:
                                                                    case RCTAlertViewStyleSecureTextInput:
                                                                        callback(@[buttonKey, [weakAlertController.textFields.firstObject text]]);
                                                                        break;
                                                                    case RCTAlertViewStyleLoginAndPasswordInput: {
                                                                        NSDictionary<NSString *, NSString *> *loginCredentials = @{
                                                                                                                                   @"login": [weakAlertController.textFields.firstObject text],
                                                                                                                                   @"password": [weakAlertController.textFields.lastObject text]
                                                                                                                                   };
                                                                        callback(@[buttonKey, loginCredentials]);
                                                                        break;
                                                                    }
                                                                    case RCTAlertViewStyleDefault:
                                                                        callback(@[buttonKey]);
                                                                        break;
                                                                }
                                                            }];
        
        //在这里取颜色值
        
        NSString *colorStr =  buttonDic[@"1"];
        if ( colorStr.length > 0) {
            UIColor *color = [UIColor colorWithHexString:colorStr];
            [alertAction setValue:color forKey:@"titleTextColor"];
        }
        if(args[@"quare"] && [args[@"quare"][@"isQuare"] boolValue]){
            UIView * subView =[alertController.view.subviews firstObject];
            subView.backgroundColor = [UIColor colorWithHexString:@"f9f9f9"];
        }
        [alertController addAction:alertAction];
        
        
    }
    
    if (!_alertControllers) {
        _alertControllers = [NSHashTable weakObjectsHashTable];
    }
    [_alertControllers addObject:alertController];
    
    [presentingController presentViewController:alertController animated:YES completion:nil];
}

@end
