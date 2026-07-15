#ifndef Nally_Bridging_Header_h
#define Nally_Bridging_Header_h

#import "CommonType.h"
#import <Cocoa/Cocoa.h>
#import "encoding.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#include <util.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <termios.h>

// Category removed as it is now implemented in Swift extension
@interface NSWindow (YLPrivateShadow)
- (void)_setContentHasShadow:(BOOL)hasShadow;
@end

#endif /* Nally_Bridging_Header_h */
