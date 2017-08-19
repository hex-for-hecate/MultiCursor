//
//  IOHIDElementCollectionView.h
//  HID_Calibrator
//
//  Created by George Warner on 3/27/11.
//  Copyright 2011 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MyLevelIndicatorView.h"

@interface IOHIDElementCollectionViewItem : NSCollectionViewItem
@property (unsafe_unretained, readonly) IBOutlet MyLevelIndicatorView   *levelIndicatorView;
@end
