//
//  MyLevelIndicatorView.h
//  HID_Calibrator
//
//  Created by George Warner on 4/1/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IOHIDElementModel.h"


@interface MyLevelIndicatorView : NSView 
@property (assign, readwrite) 	IOHIDElementModel *	representedObject;

// this is a fake property used as a binding so changes to our element 
// model's calVal property will tell this view to update.
@property (assign, readwrite) 	double	reDraw;
@end
