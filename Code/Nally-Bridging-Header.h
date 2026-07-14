#ifndef Nally_Bridging_Header_h
#define Nally_Bridging_Header_h

#import "CommonType.h"
#import <Cocoa/Cocoa.h>
#import "YLController.h"
#import "YLView.h"
#import "encoding.h"
#include <util.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <termios.h>
@interface YLView (SwiftBridge)
- (id)swiftFrontMostTerminal;
@end

@interface NSUserDefaults (myColorSupport)
- (void)setMyColor:(NSColor *)aColor forKey:(NSString *)aKey;
- (NSColor *)myColorForKey:(NSString *)aKey;
@end

#endif /* Nally_Bridging_Header_h */
