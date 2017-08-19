//
//  HIDElementModel.h
//  HID_Calibrator
//
//  Created by George Warner on 3/26/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "HID_Utilities_External.h"

@interface IOHIDElementModel : NSObject 

-(id)initWithIOHIDElementRef:(IOHIDElementRef)inIOHIDElementRef;

@property(unsafe_unretained, readonly) NSString * description;
@property(nonatomic, assign, readwrite) IOHIDElementRef _IOHIDElementRef;

@property (readonly) double logMin, logMax;
@property (readonly) double phyMin, phyMax;
@property (assign, readwrite) double phyVal;
@property (assign, readwrite) double satMin, satMax;
@property (assign, readwrite) double calMin, calMax, calVal;
@property (assign, readwrite) double deadzoneMin, deadzoneMax;

@end
