//
//  MouseManager.m
//  SimpleHID-CLI
//
//  Created by Germán Leiva on 19/08/2017.
//

#import "MouseManager.h"
#import "DDHidLib.h"

@implementation MouseManager

- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX {
    NSLog(@"xChanged");
}
- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY {
    NSLog(@"yChanged");

}
- (void) ddhidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel {
    NSLog(@"wheelChanged");

}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber {
    NSLog(@"buttonDown");

}
- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber {
    NSLog(@"buttonUp");

}


@end
