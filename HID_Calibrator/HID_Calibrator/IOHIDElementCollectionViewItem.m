//
//  IOHIDElementCollectionView.m
//  HID_Calibrator
//
//  Created by George Warner on 3/27/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import "IOHIDElementCollectionViewItem.h"

@interface IOHIDElementCollectionViewItem ()
{
@private
	__unsafe_unretained IBOutlet MyLevelIndicatorView   *levelIndicatorView;
}
@end

//
//
//
@implementation IOHIDElementCollectionViewItem

@synthesize levelIndicatorView;

//
//
//
- (void)dealloc
{
	//NSLogDebug(@"self: <%@>", self);
#if false
	// remove bindings for the level indicator
	[levelIndicatorView unbind:@"logMin"];
	[levelIndicatorView unbind:@"logMax"];

	[levelIndicatorView unbind:@"phyMin"];
	[levelIndicatorView unbind:@"phyMax"];
	[levelIndicatorView unbind:@"phyVal"];

    [levelIndicatorView unbind:@"satMin"];
	[levelIndicatorView unbind:@"satMax"];

	[levelIndicatorView unbind:@"calMin"];
	[levelIndicatorView unbind:@"calMax"];
	[levelIndicatorView unbind:@"calVal"];

    [levelIndicatorView unbind:@"deadzoneMin"];
	[levelIndicatorView unbind:@"deadzoneMax"];
#endif
}

//
//
//
#if true
- (id)copyWithZone:(NSZone *)zone
{
	//NSLogDebug(@"self(%p): <%@>", self, self);
	id result = [super copyWithZone:zone];
	[NSBundle loadNibNamed:@"IOHIDElementCollectionView" owner:result];
	return result;
}
#endif

#if true
- (void)setRepresentedObject:(id)object {
    [super setRepresentedObject:object];

    if (!object) {
        return;
	}
	//NSLogDebug(@"self: <%@>, object: <%@>", self, object);

	levelIndicatorView.representedObject = object;

	//	[levelIndicatorView bind:@"calVal" toObject:object withKeyPath:@".representedObject.phyMin" options:NULL];
#if false
	// setup bindings for the level indicator

    // Logical
	[levelIndicatorView bind:@"logMin"
				toObject:object
			 withKeyPath:@"logMin"
				 options:NULL];
	[levelIndicatorView bind:@"logMax"
				toObject:object
			 withKeyPath:@"logMax"
				 options:NULL];

    // Physical
    [levelIndicatorView bind:@"phyMin"
				toObject:object
			 withKeyPath:@"phyMin"
				 options:NULL];
	[levelIndicatorView bind:@"phyMax"
				toObject:object
			 withKeyPath:@"phyMax"
				 options:NULL];
	[levelIndicatorView bind:@"phyVal"
				toObject:object
			 withKeyPath:@"phyVal"
				 options:NULL];
    // Saturation
	[levelIndicatorView bind:@"satMin"
				toObject:object
			 withKeyPath:@"satMin"
				 options:NULL];
	[levelIndicatorView bind:@"satMax"
				toObject:object
			 withKeyPath:@"satMax"
				 options:NULL];

    // Calibration
	[levelIndicatorView bind:@"calMin"
				toObject:object
			 withKeyPath:@"calMin"
				 options:NULL];
	[levelIndicatorView bind:@"calMax"
				toObject:object
			 withKeyPath:@"calMax"
				 options:NULL];
	[levelIndicatorView bind:@"calVal"
				toObject:object
			 withKeyPath:@"calVal"
				 options:NULL];
    // deadzone
	[levelIndicatorView bind:@"deadzoneMin"
				toObject:object
			 withKeyPath:@"deadzoneMin"
				 options:NULL];
	[levelIndicatorView bind:@"deadzoneMax"
				toObject:object
			 withKeyPath:@"deadzoneMax"
				 options:NULL];

	//levelIndicatorView.first = YES;	// force initial values to be (re)set
#endif

}
#endif

@end
