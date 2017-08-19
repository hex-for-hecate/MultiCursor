//
//  IOHIDDeviceView.m
//  HID_Calibrator
//
//  Created by George Warner on 6/17/13.
//  Copyright (c) 2013 Apple Inc. All rights reserved.
//

#include "HID_Utilities_External.h"

#import "IOHIDDeviceWindowCtrl.h"

#import "IOHIDDeviceView.h"

@implementation IOHIDDeviceView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
	NSRect bounds = [self bounds];

	[[NSColor colorWithDeviceWhite:0.75f alpha:1.f] set];
    NSRectFill(bounds);

    IOHIDDeviceWindowCtrl * windowCtrl = self.window.windowController;
    IOHIDDeviceRef tIOHIDDeviceRef = windowCtrl._IOHIDDeviceRef;

    if (tIOHIDDeviceRef) {

        NSMutableString * string = [[NSMutableString alloc] init];

        uint32_t vendorID = IOHIDDevice_GetVendorID(tIOHIDDeviceRef);
        uint32_t productID = IOHIDDevice_GetProductID(tIOHIDDeviceRef);
        [string appendFormat:@"vendor ID: 0x%04X, product ID: 0x%04X,\r", vendorID, productID];

        uint32_t usagePage = IOHIDDevice_GetUsagePage(tIOHIDDeviceRef);
        uint32_t usage = IOHIDDevice_GetUsage(tIOHIDDeviceRef);
        if (!usagePage || !usage) {
            usagePage = IOHIDDevice_GetPrimaryUsagePage(tIOHIDDeviceRef);
            usage = IOHIDDevice_GetPrimaryUsage(tIOHIDDeviceRef);
        }
        [string appendFormat:@"usage: 0x%04X:0x%04X, ", usagePage, usage];

        CFStringRef tCFStringRef = HIDCopyUsageName(usagePage, usage);
        if (tCFStringRef) {
            [string appendFormat:@"\"%@\"\r", tCFStringRef];
            CFRelease(tCFStringRef);
        } else {
            [string appendFormat:@"\r"];
        }

        tCFStringRef = IOHIDDevice_GetTransport(tIOHIDDeviceRef);
        if (tCFStringRef) {
            [string appendFormat:@"Transport: \"%@\", ", tCFStringRef];
        }

        uint32_t vendorIDSource = IOHIDDevice_GetVendorIDSource(tIOHIDDeviceRef);
        if (vendorIDSource) {
            [string appendFormat:@"VendorIDSource: %u, ", vendorIDSource];
        }

        uint32_t version = IOHIDDevice_GetVersionNumber(tIOHIDDeviceRef);
        if (version) {
            [string appendFormat:@"version: %u, ", version];
        }

        tCFStringRef = IOHIDDevice_GetSerialNumber(tIOHIDDeviceRef);
        if (tCFStringRef) {
            [string appendFormat:@"SerialNumber: \"%@\", ", tCFStringRef];
        }

        uint32_t country = IOHIDDevice_GetCountryCode(tIOHIDDeviceRef);
        if (country) {
            [string appendFormat:@"CountryCode: %u, ", country];
        }

        uint32_t locationID = IOHIDDevice_GetLocationID(tIOHIDDeviceRef);
        if (locationID) {
            [string appendFormat:@"locationID: 0x%08X, ", locationID];
        }
#if false
        CFArrayRef pairs = IOHIDDevice_GetUsagePairs(tIOHIDDeviceRef);
        if (pairs) {
            CFIndex idx, cnt = CFArrayGetCount(pairs);
            for (idx = 0; idx < cnt; idx++) {
                const void *pair = CFArrayGetValueAtIndex(pairs, idx);
                CFShow(pair);
            }
        }
#endif // if false
        uint32_t maxInputReportSize = IOHIDDevice_GetMaxInputReportSize(tIOHIDDeviceRef);
        if (maxInputReportSize) {
            [string appendFormat:@"MaxInputReportSize: %u, ", maxInputReportSize];
        }

        uint32_t maxOutputReportSize = IOHIDDevice_GetMaxOutputReportSize(tIOHIDDeviceRef);
        if (maxOutputReportSize) {
            [string appendFormat:@"MaxOutputReportSize: %u, ", maxOutputReportSize];
        }

        uint32_t maxFeatureReportSize = IOHIDDevice_GetMaxFeatureReportSize(tIOHIDDeviceRef);
        if (maxFeatureReportSize) {
            [string appendFormat:@"MaxFeatureReportSize: %u, ", maxOutputReportSize];
        }

        uint32_t reportInterval = IOHIDDevice_GetReportInterval(tIOHIDDeviceRef);
        if (reportInterval) {
            [string appendFormat:@"ReportInterval: %u, ", reportInterval];
        }

        IOHIDQueueRef queueRef = IOHIDDevice_GetQueue(tIOHIDDeviceRef);
        if (queueRef) {
            [string appendFormat:@"queue: %p, ", queueRef];
        }

        IOHIDTransactionRef transactionRef = IOHIDDevice_GetTransaction(tIOHIDDeviceRef);
        if (transactionRef) {
            [string appendFormat:@"transaction: %p, ", transactionRef];
        }

        [string appendString:@"\r   (Click to recalibrate)"];

        NSFont* font = [NSFont fontWithName:@"Menlo" size:12];
        NSDictionary * attributeNormal = @{NSFontAttributeName:font,
                                           NSForegroundColorAttributeName:[NSColor blackColor]};
        [string drawInRect:NSInsetRect(bounds, 24.0, 0.0) withAttributes:attributeNormal];
	}
}

@end
