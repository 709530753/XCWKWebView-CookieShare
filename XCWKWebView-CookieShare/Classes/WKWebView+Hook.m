
#import "WKWebView+Hook.h"
#import <objc/runtime.h>

@interface WKWebViewDelegateMonitor : NSObject

+ (void)exchangeWebDelegate:(Class)aClass;

@end


@implementation WKWebView (Hook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originalMethod = class_getInstanceMethod([WKWebView class], @selector(setNavigationDelegate:));
        Method swizzledMethod = class_getInstanceMethod([WKWebView class], @selector(hook_setNavigationDelegate:));
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
    
}

- (void)hook_setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
    
    [self hook_setNavigationDelegate:delegate];
    [WKWebViewDelegateMonitor exchangeWebDelegate:delegate.class];

}

- (void)storeCookie:(NSArray *)cookies {
    NSLog(@"cookies : %@", cookies);
    for (NSHTTPCookie *cookie in cookies) {
        NSHTTPCookie *httpCookie = [self fixExpiresDateWithCookie:cookie];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:httpCookie];
    }
}

- (NSHTTPCookie *)fixExpiresDateWithCookie:(NSHTTPCookie *)cookie {
    NSMutableDictionary *propertiesDic = [[cookie properties] mutableCopy];
    if (![propertiesDic valueForKey:@"expiresDate"]) {
        propertiesDic[NSHTTPCookieExpires] = [NSDate dateWithTimeIntervalSinceNow:60*60*24*7];
        propertiesDic[NSHTTPCookieDiscard] = 0;
    }
    NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:propertiesDic];
    return newCookie;
}

@end

static void hook_exchangeMethod(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel) {
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    IMP replacedMethodIMP = method_getImplementation(replacedMethod);
    // 将样替换的方法往代理类中添加, (一般都能添加成功, 因为代理类中不会有我们自定义的函数)
    BOOL didAddMethod =
    class_addMethod(originalClass,
                    replacedSel,
                    replacedMethodIMP,
                    method_getTypeEncoding(replacedMethod));

    if (didAddMethod) {// 添加成功
        NSLog(@"class_addMethod succeed --> (%@)", NSStringFromSelector(replacedSel));
        // 获取新方法在代理类中的地址
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        // 交互原方法和自定义方法
        method_exchangeImplementations(originalMethod, newMethod);
    } else {// 如果失败, 则证明自定义方法在代理方法中, 直接交互就可以
        method_exchangeImplementations(originalMethod, replacedMethod);
    }
}

@implementation WKWebViewDelegateMonitor

+ (void)exchangeWebDelegate:(Class)aClass {
    hook_exchangeMethod(aClass, @selector(webView:didFinishNavigation:), [self class], @selector(xc_webView:didFinishNavigation:));
    hook_exchangeMethod(aClass, @selector(webView:decidePolicyForNavigationResponse:decisionHandler:), [self class], @selector(xc_webView:decidePolicyForNavigationResponse:decisionHandler:));
}

- (void)xc_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self xc_webView:webView didFinishNavigation:navigation];
}

- (void)xc_webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    if (@available(iOS 11.0, *)) {
        NSArray *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies;
        WKHTTPCookieStore *cookieStore = webView.configuration.websiteDataStore.httpCookieStore;
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStore setCookie:cookie completionHandler:^{
                NSLog(@"store succ");
            }];
        }
    } else {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];
        [webView storeCookie:cookies];
    }
    [self xc_webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
}

@end
