//
//  MouseManager.h
//  SimpleHID-CLI
//
//  Created by Germán Leiva on 19/08/2017.
//

#import <Foundation/Foundation.h>

@class DDHidMouse;

@interface MouseManager : NSObject

- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
- (void) ddhidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel;

- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;


@end
