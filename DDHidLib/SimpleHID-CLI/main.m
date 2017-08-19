//
//  main.m
//  SimpleHID-CLI
//
//  Created by Germán Leiva on 19/08/2017.
//

#import <Foundation/Foundation.h>
#import "MouseManager.h"
#import "DDHidLib.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        MouseManager *manager = [[MouseManager alloc]init];
        NSArray * mice = [DDHidMouse allMice];
        [mice makeObjectsPerformSelector: @selector(setDelegate:)
                              withObject: manager];
        [mice makeObjectsPerformSelector: @selector(startListening)
                              withObject: nil];
        NSLog(@"Hello, World! %lu",(unsigned long)mice.count);

    }
    [[NSRunLoop mainRunLoop] run];
//    return 0;
}
