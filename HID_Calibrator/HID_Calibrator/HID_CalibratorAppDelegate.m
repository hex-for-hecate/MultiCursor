//
//        File: HID_CalibratorAppDelegate.m
//    Abstract: Delegate for HID_Calibrator sample application
//     Version: 2.0
//    
//    Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
//    Inc. ("Apple") in consideration of your agreement to the following
//    terms, and your use, installation, modification or redistribution of
//    this Apple software constitutes acceptance of these terms.  If you do
//    not agree with these terms, please do not use, install, modify or
//    redistribute this Apple software.
//    
//    In consideration of your agreement to abide by the following terms, and
//    subject to these terms, Apple grants you a personal, non-exclusive
//    license, under Apple's copyrights in this original Apple software (the
//    "Apple Software"), to use, reproduce, modify and redistribute the Apple
//    Software, with or without modifications, in source and/or binary forms;
//    provided that if you redistribute the Apple Software in its entirety and
//    without modifications, you must retain this notice and the following
//    text and disclaimers in all such redistributions of the Apple Software.
//    Neither the name, trademarks, service marks or logos of Apple Inc. may
//    be used to endorse or promote products derived from the Apple Software
//    without specific prior written permission from Apple.  Except as
//    expressly stated in this notice, no other rights or licenses, express or
//    implied, are granted by Apple herein, including but not limited to any
//    patent rights that may be infringed by your derivative works or by other
//    works in which the Apple Software may be incorporated.
//    
//    The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
//    MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
//    THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
//    OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//    
//    IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
//    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//    INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
//    MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
//    AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//    STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
//    POSSIBILITY OF SUCH DAMAGE.
//    
//    Copyright (C) 2014 Apple Inc. All Rights Reserved.
//    
//
//*****************************************************
#pragma mark - complation directives
//-----------------------------------------------------

//*****************************************************
#pragma mark - includes & imports
//-----------------------------------------------------

#include "HID_Utilities_External.h"

#import "IOHIDDeviceWindowCtrl.h"

#import "HID_CalibratorAppDelegate.h"

//*****************************************************
#pragma mark - typedef's, struct's, enums, defines, etc.
//-----------------------------------------------------

//*****************************************************
#pragma mark - local ( static ) function prototypes
//-----------------------------------------------------
static OSStatus Initialize_HID(void *inContext);
static OSStatus Terminate_HID(void *inContext);

static void Handle_DeviceMatchingCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef);
static void Handle_DeviceRemovalCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef);
//*****************************************************
#pragma mark - exported globals
//-----------------------------------------------------

//*****************************************************
#pragma mark - local ( static ) globals
//-----------------------------------------------------

//*****************************************************
#pragma mark - private class interface
//-----------------------------------------------------

@interface HID_CalibratorAppDelegate ()
- (void)createWindowForHIDDevice: (IOHIDDeviceRef) inIOHIDDeviceRef;
- (void)removeWindowForHIDDevice: (IOHIDDeviceRef) inIOHIDDeviceRef;
@end

//*****************************************************
#pragma mark - public implementation
//-----------------------------------------------------

@implementation HID_CalibratorAppDelegate

- (id)init {
	NSLogDebug();
    self = [super init];
    if (self) {
		// Insert code here to initialize your application
    }
    return self;
}

- (void)dealloc {
	NSLogDebug();
}

- (void)applicationDidFinishLaunching: (NSNotification *) aNotification {
	NSLogDebug();
	windowControllers = [[NSMutableArray alloc] init];

	Initialize_HID((__bridge void *)(self));
}

- (void)applicationWillTerminate: (NSNotification *) notification {
	NSLogDebug();
	Terminate_HID((__bridge void *)(self));
}

- (void)createWindowForHIDDevice: (IOHIDDeviceRef) inIOHIDDeviceRef {
	NSLogDebug(@"(inIOHIDDeviceRef: %p)", inIOHIDDeviceRef);

	// create a new window controller for this device
	//IOHIDDeviceWindowCtrl *ioHIDDeviceWindowCtrl = [[IOHIDDeviceWindowCtrl alloc] init];
	IOHIDDeviceWindowCtrl *ioHIDDeviceWindowCtrl = [[IOHIDDeviceWindowCtrl alloc] initWithIOHIDDeviceRef:inIOHIDDeviceRef];
    [windowControllers addObject:ioHIDDeviceWindowCtrl];
} // createWindowForHIDDevice

- (void)removeWindowForHIDDevice: (IOHIDDeviceRef) inIOHIDDeviceRef {
	NSLogDebug(@"(inIOHIDDeviceRef: %p)", inIOHIDDeviceRef);

	// iterate over all IOHIDDevice Window Controllers
	for (IOHIDDeviceWindowCtrl * ioHIDDeviceWindowCtrl in windowControllers) {
		// ... if it's the controller for this hid device…
		if (ioHIDDeviceWindowCtrl._IOHIDDeviceRef == inIOHIDDeviceRef) {
			// ... then close this window
			// (removing it from this array will release it
			// which closes its window and releases all it's retained objects)
			[windowControllers removeObject:ioHIDDeviceWindowCtrl];

			//			[[ioHIDDeviceWindowCtrl window] performClose:nil];
			[[ioHIDDeviceWindowCtrl window] close];
			break;
		}
	}
} // removeWindowForHIDDevice

@synthesize windowControllers;

@end


//*****************************************************
#pragma mark - private implementation methods
//-----------------------------------------------------

// ****************************************************
#pragma mark - local ( static ) function implementations
// ----------------------------------------------------

//
//
//
static OSStatus Initialize_HID(void *inContext) {
	NSLogDebug(@"(context: %p)", inContext);

	OSStatus result = -1;

	do {    // TRY / THROW block
			// create the manager
        IOOptionBits ioOptionBits = kIOHIDManagerOptionNone;
        //IOOptionBits ioOptionBits = kIOHIDManagerOptionUsePersistentProperties;
        //IOOptionBits ioOptionBits = kIOHIDManagerOptionUsePersistentProperties | kIOHIDManagerOptionDoNotLoadProperties;
		gIOHIDManagerRef = IOHIDManagerCreate(kCFAllocatorDefault, ioOptionBits);
		if (!gIOHIDManagerRef) {
			NSLog(@"%s: Could not create IOHIDManager.\n", __PRETTY_FUNCTION__);
			break;  // THROW
		}

		// register our matching & removal callbacks
		IOHIDManagerRegisterDeviceMatchingCallback(gIOHIDManagerRef, Handle_DeviceMatchingCallback, inContext);
		IOHIDManagerRegisterDeviceRemovalCallback(gIOHIDManagerRef, Handle_DeviceRemovalCallback, inContext);

		// schedule us with the run loop
		IOHIDManagerScheduleWithRunLoop(gIOHIDManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

		// setup matching dictionary
		IOHIDManagerSetDeviceMatching(gIOHIDManagerRef, NULL);

		// open it
		IOReturn tIOReturn = IOHIDManagerOpen(gIOHIDManagerRef, kIOHIDOptionsTypeNone);
		if (kIOReturnSuccess != tIOReturn) {
			const char *errorStringPtr = GetMacOSStatusErrorString(tIOReturn);
			const char *commentStringPtr = GetMacOSStatusCommentString(tIOReturn);
			NSLog(@"%s: IOHIDManagerOpen error: 0x%08u (\"%s\" - \"%s\").\n",
			      __PRETTY_FUNCTION__,
				  tIOReturn,
			      errorStringPtr,
			      commentStringPtr);
			break;  // THROW
		}

		NSLogDebug(@"IOHIDManager (%p) creaded and opened!", (void *) gIOHIDManagerRef);
	} while (false);

Oops:;
	return (result);
}   // Initialize_HID

//
//
//
static OSStatus Terminate_HID(void *inContext) {
	NSLogDebug();
#if false
    IOHIDManagerSaveToPropertyDomain(gIOHIDManagerRef,
                                     kCFPreferencesCurrentApplication,
                                     kCFPreferencesCurrentUser,
                                     kCFPreferencesCurrentHost,
                                     kIOHIDOptionsTypeNone);
	return (IOHIDManagerClose(gIOHIDManagerRef, kIOHIDOptionsTypeNone));
#else
	return (noErr);
#endif
}

//
// this is called once for each connected device
//
static void Handle_DeviceMatchingCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef) {
#pragma unused (  inContext, inSender )

	NSLogDebug(@"(context: %p, result: 0x%08X, sender: %p, device: %p)",
               inContext, inResult, inSender, (void *) inIOHIDDeviceRef);
#ifdef DEBUG
	HIDDumpDeviceInfo(inIOHIDDeviceRef);
#endif // def DEBUG
    uint32_t vendorID = IOHIDDevice_GetVendorID(inIOHIDDeviceRef);
    uint32_t productID = IOHIDDevice_GetProductID(inIOHIDDeviceRef);
	if ((vendorID != 0x12BA) || (productID != 0x0030)) {
		[(__bridge HID_CalibratorAppDelegate *) inContext createWindowForHIDDevice: inIOHIDDeviceRef];
	}
} // Handle_DeviceMatchingCallback

//
// this is called once for each disconnected device
//
static void Handle_DeviceRemovalCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef) {
#pragma unused (  inContext, inResult, inSender )

	NSLogDebug("(context: %p, result: 0x%08X, sender: %p, device: %p).\n",
               inContext, inResult, inSender, (void *) inIOHIDDeviceRef);

	[(__bridge HID_CalibratorAppDelegate *) inContext removeWindowForHIDDevice: inIOHIDDeviceRef];
} // Handle_DeviceRemovalCallback
