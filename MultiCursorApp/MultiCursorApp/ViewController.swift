//
//  ViewController.swift
//  MultiCursorApp
//
//  Created by Germán Leiva on 19/08/2017.
//  Copyright © 2017 ExSitu. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    var mouseLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        print("uniqueID \(event.uniqueID)")
        print("pointingDeviceSerialNumber \(event.pointingDeviceSerialNumber)")
        print("vendorPointingDeviceType \(event.vendorPointingDeviceType)")
        print("pointingDeviceID \(event.pointingDeviceID)")
        print("vendorID \(event.vendorID)")
        print("deviceID \(event.deviceID)")
        print("systemTabletID \(event.systemTabletID)")
        print("tabletID \(event.tabletID)")
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        print("uniqueID \(event.uniqueID)")
        print("pointingDeviceSerialNumber \(event.pointingDeviceSerialNumber)")
        print("vendorPointingDeviceType \(event.vendorPointingDeviceType)")
        print("pointingDeviceID \(event.pointingDeviceID)")
        print("vendorID \(event.vendorID)")
        print("deviceID \(event.deviceID)")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

//        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
//            self.mouseLocation = NSEvent.mouseLocation
//            NSEvent.
//            print(String(format: "%.0f, %.0f", self.mouseLocation.x, self.mouseLocation.y))
//            return $0
//        }
//        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
//            self.mouseLocation = NSEvent.mouseLocation
//            print(String(format: "%.0f, %.0f", self.mouseLocation.x, self.mouseLocation.y))
//        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}

