//
//  AppDelegate.m
//  SimpleHID
//
//  Created by Germán Leiva on 19/08/2017.
//  Copyright © 2017 ExSitu. All rights reserved.
//

#import "AppDelegate.h"
#import "DDHidLib.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSArray *mice = [DDHidMouse allMice];
    NSLog(mice);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
