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

#import "MousePaneController.h"
#import "DDHidLib.h"
#import "ButtonState.h"



@interface MousePaneController (Private)

- (void) setMouseX: (int) mouseX;
- (void) setMouseY: (int) mouseY;
- (void) setMouseWheel: (int) mouseWheel;

@end

@implementation MousePaneController

static int sMaxValue = 2500;

static int applyDelta(int current, int delta)
{
    int newValue = (current + delta) % sMaxValue;
    if (newValue < 0)
        newValue = sMaxValue + newValue;
    return newValue;
}

/* Philip: This class is *almost* what we need.
 
   It keeps track of only one mouse at a time,
   via mCurrentMouse, mMouseButtons, mMouseX, mMouseY, and mMouseWheel.
   I don't know what the m is for.
   We want to refactor it to keep track of the dynamic information on every mouse in addition to whatever static data is in a DDHidMouse. This can be done with an array of dictionaries, I think?
   If the DDHidMouseDelegate interface does not send the mouse reference along with changes, the easiest thing to do is probably to augment those methods with a self-reference in addition to a value.
   In awakeFromNib, which I think is just the init method and not an onfocus, I can start a web socket, and then I can either send information through it at every delegate receiving method, or better, have a thread which will regularly send the sum of events that have happened through the web socket.
       I guess that's only really necessary for x and y, since we want to combine those in mousemoves, while down and up can't be combined.
 Websocket library: SocketRocket
   To describe events, I will use NSDictionary, turned into JSON with JSONSerialization
   This should send over websockets and be parsable by javascript.
 
   I need static methods for building event dictionaries by receiving e.g. dx, dy, vendorid, deviceid
 makeMouseMove dx: dy: vendorId: deviceId:
 makeMouseDown button: vendorId: deviceId:
   makeMouseUp button: vendorId: deviceId:
 
   [Alternately, we can create an instance of a smaller per-mouse manager class for each mouse.]
 
 */

- (void) awakeFromNib;
{
    mCurrentMouse = 0;
    mMouseButtons = [[NSMutableArray alloc] init];
    
    // Philip: How to create data that could be sent through a websocket
    NSDictionary* dict = [[NSDictionary alloc] init];
    NSError *e = nil;
    id data = [NSJSONSerialization dataWithJSONObject:dict options: NSJSONWritingPrettyPrinted error: &e];
    
    //get all mice
    NSArray * mice = [DDHidMouse allMice];
    //make this class the delegate for all mice
    [mice makeObjectsPerformSelector: @selector(setDelegate:)
                          withObject: self];
    //make this class receive events from all mice
    [mice makeObjectsPerformSelector: @selector(startListening)
                          withObject: nil];
    [self setMice: mice];
    [self setMouseIndex: 0];
}

//=========================================================== 
//  mice 
//=========================================================== 
- (NSArray *) mice
{
    return mMice; 
}

- (void) setMice: (NSArray *) theMice
{
    if (mMice != theMice)
    {
        [mMice release];
        mMice = [theMice retain];
    }
}

- (NSArray *) mouseButtons;
{
    return mMouseButtons;
}

- (BOOL) no;
{
    return NO;
}

//=========================================================== 
// - mouseIndex
//=========================================================== 
- (NSUInteger) mouseIndex
{
    return mMouseIndex;
}

//=========================================================== 
// - setMouseIndex:
//   Philip: Gets called when a different mouse is selected in the GUI.
//           We either need to cut out all the GUI or refactor it.
//           Ignore for now.
//=========================================================== 
- (void) setMouseIndex: (NSUInteger) theMouseIndex
{
    if (mCurrentMouse != nil)
    {
        [mCurrentMouse stopListening];
        mCurrentMouse = nil;
    }
    mMouseIndex = theMouseIndex;
    [mMiceController setSelectionIndex: mMouseIndex];
    if (mMouseIndex != NSNotFound)
    {
        mCurrentMouse = [mMice objectAtIndex: mMouseIndex];
        [mCurrentMouse startListening];
        [self setMouseX: sMaxValue/2];
        [self setMouseY: sMaxValue/2];
        [self setMouseWheel: sMaxValue/2];

        [self willChangeValueForKey: @"mouseButtons"];
        [mMouseButtons removeAllObjects];
        NSArray * buttons = [mCurrentMouse buttonElements];
        NSEnumerator * e = [buttons objectEnumerator];
        DDHidElement * element;
        while (element = [e nextObject])
        {
            ButtonState * state = [[ButtonState alloc] initWithName: [[element usage] usageName]];
            [state autorelease];
            [mMouseButtons addObject: state];
        }
        [self didChangeValueForKey: @"mouseButtons"];
    }
}

- (int) maxValue;
{
    return sMaxValue;
}

//=========================================================== 
// - mouseX
//=========================================================== 
- (int) mouseX
{
    return mMouseX;
}

//=========================================================== 
// - mouseY
//=========================================================== 
- (int) mouseY
{
    return mMouseY;
}

//=========================================================== 
// - mouseWheel
//=========================================================== 
- (int) mouseWheel
{
    return mMouseWheel;
}

- (void) ddhidMouse: (DDHidMouse *) mouse xChanged: (SInt32) deltaX;
{
    [self setMouseX: applyDelta(mMouseX, deltaX)];
}

- (void) ddhidMouse: (DDHidMouse *) mouse yChanged: (SInt32) deltaY;
{
    [self setMouseY: applyDelta(mMouseY, deltaY)];
}

- (void) ddhidMouse: (DDHidMouse *) mouse wheelChanged: (SInt32) deltaWheel;
{
    // Some wheels only output -1 or +1, some output a more analog value.
    // Normalize wheel to -1%/+1% movement.
    deltaWheel = (deltaWheel/abs(deltaWheel))*(sMaxValue/100);
    [self setMouseWheel: applyDelta(mMouseWheel, deltaWheel)];
}

//===========================================================
// - buttons
//===========================================================
- (void) ddhidMouse: (DDHidMouse *) mouse buttonDown: (unsigned) buttonNumber;
{
    ButtonState * state = [mMouseButtons objectAtIndex: buttonNumber];
    [state setPressed: YES];
}

- (void) ddhidMouse: (DDHidMouse *) mouse buttonUp: (unsigned) buttonNumber;
{
    ButtonState * state = [mMouseButtons objectAtIndex: buttonNumber];
    [state setPressed: NO];
}

@end

@implementation MousePaneController (Private)

- (void) setMouseX: (int) mouseX;
{
    mMouseX = mouseX;
}

- (void) setMouseY: (int) mouseY;
{
    mMouseY = mouseY;
}

- (void) setMouseWheel: (int) mouseWheel;
{
    mMouseWheel = mouseWheel;
}

@end

