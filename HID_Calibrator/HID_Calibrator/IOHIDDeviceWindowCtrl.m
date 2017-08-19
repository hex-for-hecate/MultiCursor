//
// IOHIDDeviceWindowCtrl.m
// HID_Calibrator
//
// Created by George Warner on 3/26/11.
// Copyright 2011 Apple Inc. All rights reserved.
//
// ****************************************************
#pragma mark - complation directives *
// ----------------------------------------------------

// ****************************************************
#pragma mark - includes & imports *

// ----------------------------------------------------
#import "IOHIDElementModel.h"

#import "IOHIDDeviceWindowCtrl.h"
// ****************************************************
#pragma mark - typedef's, struct's, enums, defines, etc. *
// ----------------------------------------------------

// ****************************************************
#pragma mark - local ( static ) function prototypes *
// ----------------------------------------------------

static CFStringRef Copy_DeviceName(IOHIDDeviceRef inIOHIDDeviceRef);
static void Handle_IOHIDValueCallback(void *inContext,
                                      IOReturn inResult,
                                      void *inSender,
                                      IOHIDValueRef inIOHIDValueRef);

// ****************************************************
#pragma mark - exported globals *
// ----------------------------------------------------

// ****************************************************
#pragma mark - local ( static ) globals *
// ----------------------------------------------------

static NSPoint gCascadePoint = {0.0, 0.0};
static const NSPoint gCascadeDelta = {72.0, 0.0}; // move an inch to right

// ****************************************************
#pragma mark - private class interface *
// ----------------------------------------------------

@interface IOHIDDeviceWindowCtrl () {
@private
    IOHIDDeviceRef _IOHIDDeviceRef;
	__unsafe_unretained NSString * name;
	__unsafe_unretained NSMutableArray		*_IOHIDElementModels;	// IOHIDElementModel items
	__unsafe_unretained IBOutlet NSCollectionView	*collectionView;
    __unsafe_unretained IBOutlet NSArrayController *arrayController;
    __unsafe_unretained NSView *_IOHIDDeviceView;
//    __unsafe_unretained IBOutlet NSTextView			*textView;
}
-(IOHIDElementModel *) getIOHIDElementModelForIOHIDElementRef:(IOHIDElementRef)inIOHIDElementRef;
@property (unsafe_unretained) IBOutlet NSView *IOHIDDeviceView;
@end

// ****************************************************
#pragma mark - external class implementations *
// ----------------------------------------------------

@implementation IOHIDDeviceWindowCtrl
//
// initialization method
//
- (id) initWithIOHIDDeviceRef:(IOHIDDeviceRef)inIOHIDDeviceRef {
	NSLogDebug(@"(IOHIDDeviceRef) %@", inIOHIDDeviceRef);
	self = [super initWithWindowNibName:@"IOHIDDeviceWindow"];
	if (self) {
        // Initialization code here.
		_IOHIDElementModels = nil;
        // if 1st time through…
		if (NSEqualPoints(gCascadePoint, NSZeroPoint)) {
			NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
            // NSRect frame = [[self window] frame];
			gCascadePoint = NSMakePoint(NSMinX(screenFrame), NSMaxY(screenFrame));
		}

		NSLogDebug(@"cascadePoint: %@", NSStringFromPoint(gCascadePoint));
		[[self window] setFrameTopLeftPoint:gCascadePoint];

		gCascadePoint.x += gCascadeDelta.x;
		gCascadePoint.y += gCascadeDelta.y;

		self._IOHIDDeviceRef = inIOHIDDeviceRef;

        // now make it visible
		[self showWindow:self];

        // bring it to the front
        // [[self window] makeKeyAndOrderFront:NULL];
	}

	return (self);
}                                                                               // init

//
//
//
- (void) dealloc {
	NSLogDebug();
	_IOHIDDeviceRef = nil;
	for (IOHIDElementModel *ioHIDElementModel in _IOHIDElementModels) {
		ioHIDElementModel._IOHIDElementRef = nil;
	}

	[arrayController setContent:NULL];

    // back up our cascade point by one delta
	gCascadePoint.x -= gCascadeDelta.x;
	gCascadePoint.y -= gCascadeDelta.y;
}                                                                               // dealloc

//
//
//
- (void) windowDidLoad {
	NSLogDebug();
	[super windowDidLoad];

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
#if false
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:[self window]];
#endif                                                                          // if false
	NSSize size = NSMakeSize(480.f, 32.f);
	[collectionView setMinItemSize:size];
	[collectionView setMaxItemSize:size];
}                                                                               // windowDidLoad

- (void) windowWillClose:(NSNotification *)aNotification {
	NSLogDebug();

    // IOHIDDeviceRegisterInputValueCallback(_IOHIDDeviceRef, NULL, self);

    // [self autorelease];
}                                                                               // windowWillClose

//
//
//
- (void) set_IOHIDDeviceRef:(IOHIDDeviceRef)inIOHIDDeviceRef {
	NSLogDebug(@"(IOHIDDeviceRef: %p)", inIOHIDDeviceRef);
	if (_IOHIDDeviceRef != inIOHIDDeviceRef) {
		_IOHIDDeviceRef = inIOHIDDeviceRef;
		if (inIOHIDDeviceRef) {
            // use the device name to title the window
			CFStringRef devCFStringRef = Copy_DeviceName(inIOHIDDeviceRef);
			if (devCFStringRef) {
				[[self window] setTitle:(__bridge NSString *)devCFStringRef];
				CFRelease(devCFStringRef);
			}

            // iterate over all this devices elements creating model objects for each one
			NSMutableArray *tArray = [NSMutableArray array];

			NSArray *elements = (__bridge_transfer NSArray *)
                IOHIDDeviceCopyMatchingElements(inIOHIDDeviceRef,
                                                NULL,
                                                kIOHIDOptionsTypeNone);
			if (elements) {
				for (id element in elements) {
					IOHIDElementRef tIOHIDElementRef = (__bridge IOHIDElementRef) element;

					IOHIDElementType tIOHIDElementType = IOHIDElementGetType(tIOHIDElementRef);
					if (tIOHIDElementType > kIOHIDElementTypeInput_ScanCodes) {
						continue;
					}

					uint32_t reportSize = IOHIDElementGetReportSize(tIOHIDElementRef);
					uint32_t reportCount = IOHIDElementGetReportCount(tIOHIDElementRef);
					if ((reportSize * reportCount) > 64) {
						continue;
					}

					uint32_t usagePage = IOHIDElementGetUsagePage(tIOHIDElementRef);
					uint32_t usage = IOHIDElementGetUsage(tIOHIDElementRef);
					if (!usagePage || !usage) {
						continue;
					}
					if (-1 == usage) {
						continue;
					}
#ifdef DEBUG
					//HIDDumpElementInfo(tIOHIDElementRef);
#endif

                    // allocate an element model
					IOHIDElementModel *ioHIDElementModel = [[IOHIDElementModel alloc] initWithIOHIDElementRef:tIOHIDElementRef];

                    // set the element model object as a property of the IOHIDElementRef
                    // (so we can find it with getIOHIDElementModelForIOHIDElementRef)
					IOHIDElementSetProperty(tIOHIDElementRef,
					                        CFSTR("Element Model"),
					                        (__bridge CFTypeRef) ioHIDElementModel);

                    // and add it to our array
					[tArray addObject:ioHIDElementModel];
				}
			}

			self._IOHIDElementModels = tArray;

            // compute our frame based on the number of elements to display
			NSRect frame = [[self window] frame];
			frame.size.height = _IOHIDDeviceView.frame.size.height + (32.f * ([tArray count] + 1));
			[collectionView setFrame:frame];
            NSLogDebug(@"collectionView.frame: %@", NSStringFromRect(frame));

            // use screen frame to move our window to the top
			NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
			frame.origin.y = screenFrame.size.height;
            // limit window size to height of screen
			if (frame.size.height > screenFrame.size.height) {
				frame.origin.y = frame.size.height = screenFrame.size.height;
			}

			[[self window] setFrame:frame display:YES animate:YES];

            // use this to also set the max size
			[[self window] setMaxSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];

            //Germán
			IOHIDDeviceRegisterInputValueCallback(inIOHIDDeviceRef,
			                                      Handle_IOHIDValueCallback,
			                                      (__bridge void *)(self));
		}
	}
}                                                                               // set_IOHIDDeviceRef

//
// Make your array KVO compliant.
//
//
- (void) insertObject:(IOHIDElementModel *)inObj in_IOHIDElementModelsAtIndex:(NSUInteger)inIndex {
	NSLogDebug(@"(obj: %p, index: %lu)", inObj, (unsigned long) inIndex);
	[_IOHIDElementModels insertObject:inObj atIndex:inIndex];
}                                                                               // insertObject

//
//
//
- (void) removeObjectFrom_IOHIDElementModelsAtIndex:(NSUInteger)inIndex {
	NSLogDebug(@"(index: %lu)", (unsigned long) inIndex);
	[_IOHIDElementModels removeObjectAtIndex:inIndex];
}                                                                               // removeObjectFrom_IOHIDElementModelsAtIndex

//
//
//
- (IOHIDElementModel *) getIOHIDElementModelForIOHIDElementRef:(IOHIDElementRef)inIOHIDElementRef {
	IOHIDElementModel *result = (__bridge IOHIDElementModel *) IOHIDElementGetProperty(inIOHIDElementRef,
                                                                                       CFSTR("Element Model"));

	return (result);
}                                                                               // getIOHIDElementModelForIOHIDElementRef

-(void)mouseUp:(NSEvent *)inEvent
{
#pragma unused (inEvent)
	NSLogDebug();
    for (IOHIDElementModel * elementModel in _IOHIDElementModels) {
        double phyVal = [elementModel phyVal];
        [elementModel setSatMin:phyVal];
        [elementModel setSatMax:phyVal];
        (void) [elementModel phyVal];
    }
}
//
//
//

@synthesize _IOHIDDeviceRef;
@synthesize _IOHIDElementModels;
// @synthesize collectionView;
// @synthesize textView;
@synthesize name;

@end
// ****************************************************
#pragma mark - local ( static ) function implementations *
// ----------------------------------------------------

//
// get name of device
//
static CFStringRef Copy_DeviceName(IOHIDDeviceRef inIOHIDDeviceRef) {
	CFStringRef result = NULL;

	if (inIOHIDDeviceRef) {
		CFStringRef manCFStringRef = IOHIDDevice_GetManufacturer(inIOHIDDeviceRef);
		if (manCFStringRef) {
            // make a copy that we can CFRelease later
			CFMutableStringRef tCFStringRef = CFStringCreateMutableCopy(kCFAllocatorDefault,
			                                                            0,
			                                                            manCFStringRef);

            // trim off any trailing spaces
			while (CFStringHasSuffix(tCFStringRef,
                                     CFSTR(" ")))
			{
				CFIndex cnt = CFStringGetLength(tCFStringRef);
				if (!cnt) {
					break;
				}

				CFStringDelete(tCFStringRef,
				               CFRangeMake(cnt -
				                           1,
				                           1));
			}

			manCFStringRef = tCFStringRef;
		}

		uint32_t vendorID = IOHIDDevice_GetVendorID(inIOHIDDeviceRef);
		if (!manCFStringRef) {
			manCFStringRef = HIDCopyVendorNameFromVendorID(vendorID);
			if (!manCFStringRef) {
				manCFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault,
				                                          NULL,
                                                          CFSTR("vendor: %d"),
				                                          vendorID);
			}
		}

		CFStringRef prodCFStringRef = IOHIDDevice_GetProduct(inIOHIDDeviceRef);
		if (prodCFStringRef) {
            // make a copy that we can CFRelease later
			prodCFStringRef = CFStringCreateCopy(kCFAllocatorDefault,
			                                     prodCFStringRef);
		} else {
            // use the product ID
			uint32_t productID = IOHIDDevice_GetProductID(inIOHIDDeviceRef);
			if (productID) {
				prodCFStringRef = HIDCopyProductNameFromVendorProductID(vendorID,
				                                                        productID);
				if (!prodCFStringRef) {
                    // to make a product string
					prodCFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault,
					                                           NULL,
                                                               CFSTR("%@ - product id % d"),
					                                           manCFStringRef,
					                                           productID);
				}
			}
		}

		assert(prodCFStringRef);
        // if the product name begins with the manufacturer string...
		if (CFStringHasPrefix(prodCFStringRef,
		                      manCFStringRef))
		{
            // then just use the product name
			result = CFStringCreateCopy(kCFAllocatorDefault,
			                            prodCFStringRef);
		} else {
            // append the product name to the manufacturer
			result = CFStringCreateWithFormat(kCFAllocatorDefault,
			                                  NULL,
			                                  CFSTR("%@ - %@"),
			                                  manCFStringRef,
			                                  prodCFStringRef);
		}
		if (manCFStringRef) {
			CFRelease(	manCFStringRef);
		}
		if (prodCFStringRef) {
			CFRelease(	prodCFStringRef);
		}
	}

	return (result);
}                                                                               // Copy_DeviceName

//
//
//
static void Handle_IOHIDValueCallback(void *		inContext,
                                      IOReturn		inResult,
                                      void *		inSender,
                                      IOHIDValueRef inIOHIDValueRef) {
#pragma unused( inContext, inResult, inSender )
	IOHIDDeviceWindowCtrl *tIOHIDDeviceWindowCtrl = (__bridge IOHIDDeviceWindowCtrl *) inContext;
    // IOHIDDeviceRef tIOHIDDeviceRef = (IOHIDDeviceRef) inSender;

    //Germán
     NSLogDebug(@"===> (context: %p, result: %u, sender: %p, valueRef: %p", inContext, inResult, inSender, inIOHIDValueRef);

	do {
        // is our device still valid?
		if (!tIOHIDDeviceWindowCtrl._IOHIDDeviceRef) {
			NSLogDebug(@"tIOHIDDeviceWindowCtrl._IOHIDDeviceRef == NULL");
			break;                                                              // (no)
		}

#if false
        // is this value for this device?
		if (tIOHIDDeviceRef != tIOHIDDeviceWindowCtrl._IOHIDDeviceRef) {
			NSLogDebug(@"tIOHIDDeviceRef (%p) != _IOHIDDeviceRef (%p)",
			           tIOHIDDeviceRef,
			           tIOHIDDeviceWindowCtrl._IOHIDDeviceRef);
			break;                                                              // (no)
		}

#endif                                                                          // if false
        // is this value's element valid?
		IOHIDElementRef tIOHIDElementRef = IOHIDValueGetElement(inIOHIDValueRef);
		if (!tIOHIDElementRef) {
			NSLogDebug(@"tIOHIDElementRef == NULL");
			break;                                                              // (no)
		}

        // length ok?
		CFIndex length = IOHIDValueGetLength(inIOHIDValueRef);
		if (length > sizeof(double_t)) {
			break;                                                              // (no)
		}

        // find the element for this IOHIDElementRef
		IOHIDElementModel *tIOHIDElementModel = [tIOHIDDeviceWindowCtrl getIOHIDElementModelForIOHIDElementRef:tIOHIDElementRef];
		if (tIOHIDElementModel) {
            // update its value
			tIOHIDElementModel.phyVal = IOHIDValueGetScaledValue(inIOHIDValueRef,
			                                                     kIOHIDValueScaleTypePhysical);
		}
	} while (false);
}                                                                               // Handle_IOHIDValueCallback
