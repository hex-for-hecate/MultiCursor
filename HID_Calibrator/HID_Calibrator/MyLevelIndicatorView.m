//
// MyLevelIndicatorView.m
// HID_Calibrator
//
// Created by George Warner on 4/1/11.
// Copyright 2011 Apple Inc. All rights reserved.
//

#import "MyLevelIndicatorView.h"

@interface MyLevelIndicatorView () {
@private
	// instance variables for our properties.
	__unsafe_unretained IOHIDElementModel *representedObject;
	double reDraw;
}
@end @implementation MyLevelIndicatorView - (id) initWithFrame:(NSRect)frame {
	// NSLogDebug(@"(NSRect): %@", NSStringFromRect(frame));
	self = [super initWithFrame:frame];
	if (self) {
		// Initialization code here.
        [self setToolTip:@"Physical is red (range is pink); calibrated is green"];
	}

	return (self);
}                                                                               // initWithFrame

- (void) dealloc {
	NSLogDebug(@"self(%p): <%@>",
	           self,
	           self);
} // dealloc

- (void) setRepresentedObject:(IOHIDElementModel *)inRepresentedObject {
	representedObject = inRepresentedObject;
#if true
	// reDraw is a fake property used as a binding so changes to our element
	// model's calVal property will tell this view to update.
	[self bind:@"reDraw" toObject:representedObject withKeyPath:@"calVal" options:NULL];
#endif // if true
} // setRepresentedObject

- (IOHIDElementModel *) representedObject {
	return (representedObject);
}

- (double) reDraw {
	// NSLogDebug(@"(double) %6.2f", reDraw);
	[self setNeedsDisplay:YES];

	return (reDraw);
} // reDraw

- (void) setReDraw:(double)newReDraw {
	// NSLogDebug(@"(double) %6.2f", newReDraw);
	reDraw = newReDraw;
	// [self setNeedsDisplay:YES];
} // setReDraw

- (void) drawRect:(NSRect)dirtyRect {
	NSRect bounds = [self bounds];

#if true
	[[NSColor colorWithDeviceWhite:0.85f alpha:1.f] set];
    NSRectFill(bounds);
#endif // if true

	IOHIDElementModel *elementModel = self.representedObject;

	NSRect newBounds = bounds;
#if true
	double width = NSWidth(bounds);

	// draw the saturated range
	double phyMin = elementModel.phyMin;
	double phyMax = elementModel.phyMax;
	double phyRange = phyMax - phyMin;

	double satMin = elementModel.satMin;
	double satMax = elementModel.satMax;

	double satMinX = (satMin - phyMin) * width / phyRange;
	double satMaxX = (satMax - phyMin) * width / phyRange;
	newBounds.origin.x += satMinX;
	newBounds.size.width = (satMaxX - satMinX);
	NSColor *pinkColor = [NSColor colorWithDeviceRed:1.0f green:0.75f blue:1.0f alpha:1.f];
	[pinkColor set];
    NSRectFill(newBounds);
#if true
	// draw the deadzone range
	double deadzoneMin = elementModel.deadzoneMin;
	double deadzoneMax = elementModel.deadzoneMax;
	if (deadzoneMin < deadzoneMax) {
		double deadzoneMinX = (deadzoneMin - phyMin) * width / phyRange;
		double deadzoneMaxX = (deadzoneMax - phyMin) * width / phyRange;
		newBounds = bounds;
		newBounds.origin.x += deadzoneMinX;
		newBounds.origin.y += newBounds.size.height * 3.f / 4.f;
		newBounds.size.height /= 4.f;
		newBounds.size.width = deadzoneMaxX - deadzoneMinX + 1.f;
		[[NSColor redColor] set];
		NSRectFill(newBounds);
	}
#endif // if true

	// draw the current physical value
#if true
	double phyVal = elementModel.phyVal;
	double phyX = (phyVal - phyMin) * width / phyRange;
	newBounds = bounds;
	newBounds.origin.x += phyX;
	newBounds.size.width = 1.f;
	[[NSColor redColor] set];
    NSRectFill(newBounds);
#endif // if true

	// draw the current calibrated value
#if true
	double logMin = elementModel.logMin;
	double logMax = elementModel.logMax;
	double logRange = logMax - logMin;

	double calX = (elementModel.calVal - logMin) * width / logRange;
	newBounds = bounds;
	newBounds.origin.x += calX;
	newBounds.size.width = 1.f;
	NSColor *darkGreenColor = [NSColor colorWithDeviceRed:0.f green:0.5f blue:0.f alpha:1.f];
	[darkGreenColor set];
    NSRectFill(newBounds);
#endif // if true

	// draw the computed calibrated value
#if true
	double ccalX = (phyVal - satMin) * width / (satMax - satMin);
	if (deadzoneMin < deadzoneMax) {
		double halfWidth = width / 2.f;
		if (phyVal < deadzoneMin) {
			ccalX = (phyVal - satMin) * halfWidth / (deadzoneMin - satMin);
		} else if (deadzoneMax < phyVal) {
			ccalX = ((phyVal - deadzoneMax) * halfWidth / (satMax - deadzoneMax)) + halfWidth;
		} else {
			ccalX = halfWidth;
		}
	}

	newBounds = bounds;
	newBounds.origin.x += ccalX;
	newBounds.size.width = 1.f;
	[[NSColor blackColor] set];
    NSRectFill(newBounds);
#endif // if true

#endif // if true

#if true
	[[NSColor blackColor] set];
	NSFrameRect(bounds);
#endif // if true
}                                                                               // drawRect

@synthesize representedObject;
@synthesize reDraw;

@end
