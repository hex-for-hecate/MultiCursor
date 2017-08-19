//
// HIDElementModel.m
// HID_Calibrator
//
// Created by George Warner on 3/26/11.
// Copyright 2011 Apple Inc. All rights reserved.
//
// ****************************************************
#pragma mark - includes & imports *
// ----------------------------------------------------

#include "HID_Utilities_External.h"

#import "IOHIDElementModel.h"

@interface IOHIDElementModel ()
{
@private
	IOHIDElementRef _IOHIDElementRef;
	BOOL first;
}
@end

@implementation IOHIDElementModel

- (id)initWithIOHIDElementRef: (IOHIDElementRef) inIOHIDElementRef;
{
	//NSLogDebug(@"(IOHIDElementRef): <%@>", inIOHIDElementRef);
	self = [super init];
	if (self) {
		// Initialization code here.
		first = YES;
		self._IOHIDElementRef = inIOHIDElementRef;
	}

	return (self);
}

- (void)dealloc {
	NSLogDebug(@"self: <%@>", self);
	self._IOHIDElementRef = nil;
} // dealloc

- (NSString *) description {
	NSString *result = [NSString stringWithFormat: @"<%@ %p>", [self class ], self];
	if (_IOHIDElementRef) {
		IOHIDDeviceRef tIOHIDDeviceRef = IOHIDElementGetDevice(_IOHIDElementRef);
		uint32_t vendorID = IOHIDDevice_GetVendorID(tIOHIDDeviceRef);
		uint32_t productID = IOHIDDevice_GetProductID(tIOHIDDeviceRef);

		uint32_t usagePage = IOHIDElementGetUsagePage(_IOHIDElementRef);
		uint32_t usage = IOHIDElementGetUsage(_IOHIDElementRef);
		IOHIDElementCookie cookie = IOHIDElementGetCookie(_IOHIDElementRef);

		CFStringRef tCFStringRef = IOHIDElementGetName(_IOHIDElementRef);
		if (tCFStringRef) {
			// create a copy so it's safe to release it later
			tCFStringRef = CFStringCreateCopy(kCFAllocatorDefault, tCFStringRef);
		} else {
			tCFStringRef = HIDCopyElementNameFromVendorProductCookie(vendorID, productID, cookie);
			if (!tCFStringRef) {
				tCFStringRef = HIDCopyElementNameFromVendorProductUsage(vendorID, productID, usagePage, usage);
			}
			if (!tCFStringRef) {
				tCFStringRef = HIDCopyUsageName(usagePage, usage);
			}
		}
		if (!tCFStringRef) {   // if everything else fails…
			tCFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("element %p"), (void *) _IOHIDElementRef);
		}

		// append usage page & usage
		CFStringRef t2CFStringRef = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@: {c:%d, u:{%d:%d}}"), tCFStringRef, cookie, usagePage, usage);
		CFRelease(	tCFStringRef);

		result = [NSString stringWithString:(__bridge NSString*) t2CFStringRef];
		CFRelease(	t2CFStringRef);
	}

	// NSLogDebug(@"name: <%@>", result);
	return (result);
} // description

- (void)set_IOHIDElementRef: (IOHIDElementRef) inIOHIDElementRef {
	//NSLogDebug(@"self: %p, inIOHIDElementRef: %p", self, inIOHIDElementRef);
	if (first || (_IOHIDElementRef != inIOHIDElementRef)) {
		_IOHIDElementRef = inIOHIDElementRef;
		first = YES;

		(void) self.description;
		if (inIOHIDElementRef) {
			// save these for a second (since we're about to mess with them…)
			double tPhyMin = self.phyMin;
			double tPhyMax = self.phyMax;

			self.calMin = IOHIDElementGetLogicalMin(inIOHIDElementRef);
			self.calMax = IOHIDElementGetLogicalMax(inIOHIDElementRef);

			IOHIDElement_SetupCalibration(inIOHIDElementRef);

			// note: don't use self.phyVal here;
			// we don't want the phyVal setter to mess with the
			// minmin/maxmax values after we just set them
			//phyVal = IOHIDElement_GetValue(inIOHIDElementRef, kIOHIDValueScaleTypePhysical);

			// if the previous values were valid…
			first = (tPhyMin != tPhyMax);
		}
	}
} // set_IOHIDElementRef

/* ************************ *\
 *							*
 * Get/Set logical values	*
 *							*
 \* ************************ */

- (double)logMin {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElementGetLogicalMin(_IOHIDElementRef);
	}

	return (result);
} // logMin

- (double)logMax {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElementGetLogicalMax(_IOHIDElementRef);
	}

	return (result);
} // logMax

/* ************************ *\
 *							*
 * Get/Set Physical values	*
 *							*
 \* *********************** */

- (double)phyMin {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElementGetPhysicalMin(_IOHIDElementRef);
	}

	return (result);
} // phyMin

- (double)phyVal {
	// NSLogDebug();
	double result = NAN;

	if (_IOHIDElementRef) {
		IOHIDValueRef tIOHIDValueRef;
		IOReturn ioReturn = IOHIDDeviceGetValue(IOHIDElementGetDevice(_IOHIDElementRef), _IOHIDElementRef, &tIOHIDValueRef);
		if (kIOReturnSuccess == ioReturn) {
			result = IOHIDValueGetScaledValue(tIOHIDValueRef, kIOHIDValueScaleTypePhysical);
			if (first || (result < self.satMin)) {
				self.satMin = result;
			}
			if (first || (result > self.satMax)) {
				self.satMax = result;
			}
			first = NO;
		} else {
			NSLogDebug(@"IOHIDDeviceGetValue error: %08x.", (int) ioReturn);
		}
	}

	return (result);
} // phyVal

- (void)setPhyVal: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	self.calVal = self.calVal; // this will force the view to reload its calibrated value
} // setPhyVal

- (double)phyMax {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElementGetPhysicalMax(_IOHIDElementRef);
	}

	return (result);
} // phyMax

/* **************************** *\
 *								*
 * Get/Set saturation values	*
 *								*
 \* *************************** */

- (double)satMin {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationSaturationMin(_IOHIDElementRef);
	}

	return (result);
} // satMin

- (void)setSatMin: (double) newVal {
	//NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationSaturationMin(_IOHIDElementRef, newVal);
	self.calVal = self.calVal; // this will force the view to reload its calibrated value
} // setSatMin

- (double)satMax {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationSaturationMax(_IOHIDElementRef);
	}

	return (result);
} // satMax

- (void)setSatMax: (double) newVal {
	//NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationSaturationMax(_IOHIDElementRef, newVal);
	self.calVal = self.calVal; // this will force the view to reload its calibrated value
} // setSatMax

/* **************************** *\
 *								*
 * Get/Set calibration values	*
 *								*
 \* *************************** */


- (double)calMin {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationMin(_IOHIDElementRef);
	}

	return (result);
} // calMin

- (void)setCalMin: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationMin(_IOHIDElementRef, newVal);
} // setCalMin

- (double)calVal {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		IOHIDValueRef tIOHIDValueRef = NULL;
		IOReturn ioReturn = IOHIDDeviceGetValue(IOHIDElementGetDevice(_IOHIDElementRef), _IOHIDElementRef, &tIOHIDValueRef);
		if (kIOReturnSuccess == ioReturn) {
			result = IOHIDValueGetScaledValue(tIOHIDValueRef, kIOHIDValueScaleTypeCalibrated);
		} else {
			NSLogDebug(@"IOHIDDeviceGetValue error: %08x.", (int) ioReturn);
		}
	}

	return (result);
} // calVal

- (void)setCalVal: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	//calVal = newVal;
}

- (double)calMax {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationMax(_IOHIDElementRef);
	}

	return (result);
} // calMax

- (void)setCalMax: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationMax(_IOHIDElementRef, newVal);
} // setCalMax

/* ************************* *\
 *							 *
 * Get/Set deadzone values	 *
 *							 *
 \* ************************ */

- (double)deadzoneMin {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationDeadZoneMin(_IOHIDElementRef);
	}

	return (result);
} // deadzoneMin

- (void)setDeadzoneMin: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationDeadZoneMin(_IOHIDElementRef, newVal);
	self.calVal = self.calVal; // this will force the view to reload its calibrated value
} // setDeadzoneMin

- (double)deadzoneMax {
	// NSLogDebug();
	double result = NAN;
	if (_IOHIDElementRef) {
		result = IOHIDElement_GetCalibrationDeadZoneMax(_IOHIDElementRef);
	}

	return (result);
} // deadzoneMax

- (void)setDeadzoneMax: (double) newVal {
	// NSLogDebug(@"(double) %6.2f", newVal);
	IOHIDElement_SetCalibrationDeadZoneMax(_IOHIDElementRef, newVal);
	self.calVal = self.calVal; // this will force the view to reload its calibrated value
} // setDeadzoneMax

@dynamic description;
@synthesize _IOHIDElementRef;
@end
