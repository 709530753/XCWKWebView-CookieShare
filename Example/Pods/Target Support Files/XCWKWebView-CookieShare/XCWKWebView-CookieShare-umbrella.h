#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "WKWebView+Hook.h"

FOUNDATION_EXPORT double XCWKWebView_CookieShareVersionNumber;
FOUNDATION_EXPORT const unsigned char XCWKWebView_CookieShareVersionString[];

