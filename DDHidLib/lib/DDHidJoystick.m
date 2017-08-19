/*
 * Copyright (c) 2007 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "DDHidLib.h"
#include <IOKit/hid/IOHIDUsageTables.h>

@interface DDHidJoystick (DDHidJoystickDelegate)

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (NSUInteger) stick
              xChanged: (NSInteger) value;

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (NSUInteger) stick
              yChanged: (NSInteger) value;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (NSUInteger) stick
             otherAxis: (NSUInteger) otherAxis
          valueChanged: (NSInteger) value;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (NSUInteger) stick
             povNumber: (NSUInteger) povNumber
          valueChanged: (NSInteger) value;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
            buttonDown: (NSUInteger) buttonNumber;

- (void) ddhidJoystick: (DDHidJoystick *) joystick
              buttonUp: (NSUInteger) buttonNumber;

@end

@interface DDHidJoystick (Private)

- (void) initLogicalDeviceElements;
- (void) initJoystickElements: (NSArray *) elements;
- (void) addStick: (NSArray *) stickElements;
- (void) ddhidQueueHasEvents: (DDHidQueue *) hidQueue;

- (NSInteger) normalizeValue: (NSInteger) value
            forElement: (DDHidElement *) element;

- (NSInteger) povValue: (NSInteger) value
            forElement: (DDHidElement *) element;

- (BOOL) findStick: (NSUInteger *) stick
           element: (DDHidElement **) elementOut
   withXAxisCookie: (IOHIDElementCookie) cookie;

- (BOOL) findStick: (NSUInteger *) stick
           element: (DDHidElement **) elementOut
   withYAxisCookie: (IOHIDElementCookie) cookie;

- (BOOL) findStick: (NSUInteger *) stickOut
         otherAxis: (NSUInteger *) axisOut
           element: (DDHidElement **) elementOut
        withCookie: (IOHIDElementCookie) cookie;

- (BOOL) findStick: (NSUInteger *) stickOut
         povNumber: (NSUInteger *) povNumber
           element: (DDHidElement **) elementOut
        withCookie: (IOHIDElementCookie) cookie;

@end

@implementation DDHidJoystick

+ (NSArray *) allJoysticks;
{
    NSArray * joysticks =
        [DDHidDevice allDevicesMatchingUsagePage: kHIDPage_GenericDesktop
                                         usageId: kHIDUsage_GD_Joystick
                                       withClass: self
                               skipZeroLocations: YES];
    NSArray * gamepads =
        [DDHidDevice allDevicesMatchingUsagePage: kHIDPage_GenericDesktop
                                         usageId: kHIDUsage_GD_GamePad
                                       withClass: self
                               skipZeroLocations: YES];

    NSMutableArray * allJoysticks = [NSMutableArray arrayWithArray: joysticks];
    [allJoysticks addObjectsFromArray: gamepads];
    [allJoysticks sortUsingSelector: @selector(compareByLocationId:)];
    return allJoysticks;
}

- (id) initLogicalWithDevice: (io_object_t) device 
         logicalDeviceNumber: (int) logicalDeviceNumber
                       error: (NSError **) error;
{
    self = [super initLogicalWithDevice: device
                    logicalDeviceNumber: logicalDeviceNumber
                                  error: error];
    if (self == nil)
        return nil;
    
    mButtonElements = [[NSMutableArray alloc] init];
    mSticks = [[NSMutableArray alloc] init];
    mLogicalDeviceElements = [[NSMutableArray alloc] init];

    [self initLogicalDeviceElements];
    NSUInteger logicalDeviceCount = [mLogicalDeviceElements count];
    if (logicalDeviceCount ==  0)
    {
        [self release];
        return nil;
    }

    mLogicalDeviceNumber = logicalDeviceNumber;
    if (mLogicalDeviceNumber >= logicalDeviceCount)
        mLogicalDeviceNumber = logicalDeviceCount - 1;
    
    [self initJoystickElements:
        [mLogicalDeviceElements objectAtIndex: mLogicalDeviceNumber]];
    [mButtonElements sortUsingSelector: @selector(compareByUsage:)];
    mDelegate = nil;
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mLogicalDeviceElements release];
    [mSticks release];
    [mButtonElements release];
    
    mLogicalDeviceElements = nil;
    mSticks = nil;
    mButtonElements = nil;
    [super dealloc];
}

- (NSUInteger) logicalDeviceCount;
{
    return [mLogicalDeviceElements count];
}

#pragma mark -
#pragma mark Joystick Elements

//=========================================================== 
// - buttonElements
//=========================================================== 
- (NSArray *) buttonElements;
{
    return mButtonElements; 
}

- (NSUInteger) numberOfButtons;
{
    return [mButtonElements count];
}

#pragma mark -
#pragma mark Sticks - indexed accessors

- (NSUInteger) countOfSticks 
{
    return [mSticks count];
}

- (DDHidJoystickStick *) objectInSticksAtIndex: (NSUInteger)index
{
    return [mSticks objectAtIndex: index];
}

- (void) addElementsToQueue: (DDHidQueue *) queue;
{
    NSEnumerator * e = [mSticks objectEnumerator];
    DDHidJoystickStick * stick;
    while (stick = [e nextObject])
    {
        [queue addElements: [stick allElements]];
    }
    
    [queue addElements: mButtonElements];
}


#pragma mark -
#pragma mark Asynchronous Notification

- (void) setDelegate: (id) delegate;
{
    mDelegate = delegate;
}

- (void) addElementsToDefaultQueue;
{
    [self addElementsToQueue: mDefaultQueue];
}

@end

@implementation DDHidJoystick (Private)

- (void) initLogicalDeviceElements;
{
    NSArray * topLevelElements = [self elements];
    if ([topLevelElements count] == 0)
    {
        [mLogicalDeviceElements addObject: topLevelElements];
        return;
    }
    
    NSEnumerator * e = [topLevelElements objectEnumerator];
    DDHidElement * element;
    while (element = [e nextObject])
    {
        unsigned usagePage = [[element usage] usagePage];
        unsigned usageId = [[element usage] usageId];
        if (usagePage == kHIDPage_GenericDesktop &&
            (usageId == kHIDUsage_GD_Joystick || usageId == kHIDUsage_GD_GamePad)) 
        {
            [mLogicalDeviceElements addObject: [NSArray arrayWithObject: element]];
        }
    }
}

- (void) initJoystickElements: (NSArray *) elements;
{
    NSEnumerator * e = [elements objectEnumerator];
    DDHidElement * element;
    DDHidJoystickStick * currentStick = [[[DDHidJoystickStick alloc] init] autorelease];
    BOOL stickHasElements = NO;

    while (element = [e nextObject])
    {
        unsigned usagePage = [[element usage] usagePage];
        unsigned usageId = [[element usage] usageId];
        NSArray * subElements = [element elements];
        
        if ([subElements count] > 0)
        {
            [self initJoystickElements: subElements];
        }
        else if ((usagePage == kHIDPage_GenericDesktop) &&
            (usageId == kHIDUsage_GD_Pointer))
        {
            [self addStick: subElements];
        }
        else if ([currentStick addElement: element])
        {
            stickHasElements = YES;
        }
        else if ((usagePage == kHIDPage_Button) &&
                 (usageId > 0))
        {
            [mButtonElements addObject: element];
        }
    }
    if (stickHasElements)
    {
        [mSticks addObject: currentStick];
    }
}

- (void) addStick: (NSArray *) elements;
{
    NSEnumerator * e = [elements objectEnumerator];
    DDHidElement * element;
    while (element = [e nextObject])
    {
        NSLog(@"Stick element: %@", [[element usage] usageName]);
    }
}

- (void) ddhidQueueHasEvents: (DDHidQueue *) hidQueue;
{
    DDHidEvent * event;
    while ((event = [hidQueue nextEvent]))
    {
        IOHIDElementCookie cookie = [event elementCookie];
        SInt32 value = [event value];
        DDHidElement * element;
        NSUInteger stick;
        NSUInteger otherAxis;
        NSUInteger povNumber;
        if ([self findStick: &stick element: &element withXAxisCookie: cookie])
        {
            NSInteger normalizedValue = [self normalizeValue: value forElement: element];
            [self ddhidJoystick: self stick: stick xChanged: normalizedValue];
        }
        else if ([self findStick: &stick element: &element withYAxisCookie: cookie])
        {
            NSInteger normalizedValue = [self normalizeValue: value forElement: element];
            [self ddhidJoystick: self stick: stick yChanged: normalizedValue];
        }
        else if ([self findStick: &stick otherAxis: &otherAxis element: &element
                      withCookie: cookie])
        {
            NSInteger normalizedValue = [self normalizeValue: value forElement: element];
            [self ddhidJoystick: self stick: stick
                      otherAxis: otherAxis valueChanged: normalizedValue];
        }
        else if ([self findStick: &stick povNumber: &povNumber element: &element
                      withCookie: cookie])
        {
            NSInteger povValue = [self povValue: value forElement: element];
            [self ddhidJoystick: self stick: stick
                      povNumber: povNumber valueChanged: povValue];
        }
        else
        {
            unsigned i = 0;
            for (i = 0; i < [[self buttonElements] count]; i++)
            {
                if (cookie == [[[self buttonElements] objectAtIndex: i] cookie])
                    break;
            }
            
            if (value == 1)
            {
                [self ddhidJoystick: self buttonDown: i];
            }
            else if (value == 0)
            {
                [self ddhidJoystick: self buttonUp: i];
            }
            else
            {
                DDHidElement * element = [self elementForCookie: [event elementCookie]];
                NSLog(@"Element: %@, value: %d", [[element usage] usageName], (int)[event value]);
            }
        }
    }
}

- (NSInteger) normalizeValue: (NSInteger) value
            forElement: (DDHidElement *) element;
{
    NSInteger normalizedUnits = DDHID_JOYSTICK_VALUE_MAX - DDHID_JOYSTICK_VALUE_MIN;
    NSInteger elementUnits = [element maxValue] - [element minValue];
    
    NSInteger normalizedValue = (((value - [element minValue]) * normalizedUnits) / elementUnits) + DDHID_JOYSTICK_VALUE_MIN;
    return normalizedValue;
}

- (NSInteger) povValue: (NSInteger) value
      forElement: (DDHidElement *) element;
{
    NSInteger max = [element maxValue];
    NSInteger min = [element minValue];
    
    // If the value is outside the min/max range, it's probably in a
    // centered/NULL state.
    if ((value < min) || (value > max))
    {
        return -1;
    }
    
    // Do like DirectInput and express the hatswitch value in hundredths of a
	// degree, clockwise from north.
	return 36000 / (max - min + 1) * (value - min);
}

- (BOOL) findStick: (NSUInteger *) stick
           element: (DDHidElement **) elementOut
   withXAxisCookie: (IOHIDElementCookie) cookie;
{
    NSUInteger i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidElement * element = [[mSticks objectAtIndex: i] xAxisElement];
        if ((element != nil) && ([element cookie] == cookie))
        {
            *stick = i;
            *elementOut = element;
            return YES;
        }
    }
    return NO;
}

- (BOOL) findStick: (NSUInteger *) stick
           element: (DDHidElement **) elementOut
   withYAxisCookie: (IOHIDElementCookie) cookie;
{
    NSUInteger i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidElement * element = [[mSticks objectAtIndex: i] yAxisElement];
        if ((element != nil) && ([element cookie] == cookie))
        {
            *stick = i;
            *elementOut = element;
            return YES;
        }
    }
    return NO;
}

- (BOOL) findStick: (NSUInteger *) stickOut
         otherAxis: (NSUInteger *) axisOut
           element: (DDHidElement **) elementOut
        withCookie: (IOHIDElementCookie) cookie;
{
    unsigned i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidJoystickStick * stick = [mSticks objectAtIndex: i];
        unsigned j;
        for (j = 0; j < [stick countOfStickElements]; j++)
        {
            DDHidElement * element = [stick objectInStickElementsAtIndex: j];
            if ((element != nil) && ([element cookie] == cookie))
            {
                *stickOut = i;
                *axisOut = j;
                *elementOut = element;
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL) findStick: (NSUInteger *) stickOut
         povNumber: (NSUInteger *) povNumber
           element: (DDHidElement **) elementOut
        withCookie: (IOHIDElementCookie) cookie;
{
    unsigned i;
    for (i = 0; i < [mSticks count]; i++)
    {
        DDHidJoystickStick * stick = [mSticks objectAtIndex: i];
        unsigned j;
        for (j = 0; j < [stick countOfPovElements]; j++)
        {
            DDHidElement * element = [stick objectInPovElementsAtIndex: j];
            if ((element != nil) && ([element cookie] == cookie))
            {
                *stickOut = i;
                *povNumber = j;
                *elementOut = element;
                return YES;
            }
        }
    }
    return NO;
}

@end

@implementation DDHidJoystick (DDHidJoystickDelegate)

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (NSUInteger) stick
              xChanged: (NSInteger) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick stick: stick xChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (NSUInteger) stick
              yChanged: (NSInteger) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick stick: stick yChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (NSUInteger) stick
             otherAxis: (NSUInteger) otherAxis
          valueChanged: (NSInteger) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick stick: stick otherAxis: otherAxis
                    valueChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
                 stick: (NSUInteger) stick
             povNumber: (NSUInteger) povNumber
          valueChanged: (NSInteger) value;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick stick: stick povNumber: povNumber
                    valueChanged: value];
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
            buttonDown: (NSUInteger) buttonNumber;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick buttonDown: buttonNumber];
}

- (void) ddhidJoystick: (DDHidJoystick *) joystick
              buttonUp: (NSUInteger) buttonNumber;
{
    if ([mDelegate respondsToSelector: _cmd])
        [mDelegate ddhidJoystick: joystick buttonUp: buttonNumber];
}

@end

@implementation DDHidJoystickStick

- (id) init
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mXAxisElement = nil;
    mYAxisElement = nil;
    mStickElements = [[NSMutableArray alloc] init];
    mPovElements = [[NSMutableArray alloc] init];
    
    return self;
}

//=========================================================== 
// dealloc
//=========================================================== 
- (void) dealloc
{
    [mXAxisElement release];
    [mYAxisElement release];
    [mStickElements release];
    [mPovElements release];
    
    mXAxisElement = nil;
    mYAxisElement = nil;
    mStickElements = nil;
    mPovElements = nil;
    [super dealloc];
}

-  (BOOL) addElement: (DDHidElement *) element;
{
    DDHidUsage * usage = [element usage];
    if ([usage usagePage] != kHIDPage_GenericDesktop)
        return NO;
    
    BOOL elementAdded = YES;
    switch ([usage usageId])
    {
        case kHIDUsage_GD_X:
            if (mXAxisElement == nil)
                mXAxisElement = [element retain];
            else
                [mStickElements addObject: element];
            break;
            
        case kHIDUsage_GD_Y:
            if (mYAxisElement == nil)
                mYAxisElement = [element retain];
            else
                [mStickElements addObject: element];
            break;
            
        case kHIDUsage_GD_Z:
        case kHIDUsage_GD_Rx:
        case kHIDUsage_GD_Ry:
        case kHIDUsage_GD_Rz:
            [mStickElements addObject: element];
            break;
            
        case kHIDUsage_GD_Hatswitch:
            [mPovElements addObject: element];
            break;
            
        default:
            elementAdded = NO;
            
    }
    
    return elementAdded;
}

- (NSArray *) allElements;
{
    NSMutableArray * elements = [NSMutableArray array];
    if (mXAxisElement != nil)
        [elements addObject: mXAxisElement];
    if (mYAxisElement != nil)
        [elements addObject: mYAxisElement];
    [elements addObjectsFromArray: mStickElements];
    [elements addObjectsFromArray: mPovElements];
    return elements;
}

- (DDHidElement *) xAxisElement;
{
    return mXAxisElement;
}

- (DDHidElement *) yAxisElement;
{
    return mYAxisElement;
}

#pragma mark -
#pragma mark mStickElements - indexed accessors

- (NSUInteger) countOfStickElements
{
    return [mStickElements count];
}

- (DDHidElement *) objectInStickElementsAtIndex: (NSUInteger)index
{
    return [mStickElements objectAtIndex: index];
}

#pragma mark -
#pragma mark PovElements - indexed accessors

- (NSUInteger) countOfPovElements;
{
    return [mPovElements count];
}

- (DDHidElement *) objectInPovElementsAtIndex: (NSUInteger)index;
{
    return [mPovElements objectAtIndex: index];
}

- (NSString *) description;
{
    return [mStickElements description];
}

@end
