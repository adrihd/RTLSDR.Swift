//
//  USBManager.swift
//  waveSDR
//
//  Copyright © 2019 GetOffMyHack. All rights reserved.
//

import Foundation
import IOKit
import IOKit.usb

//--------------------------------------------------------------------------
//
// MARK: - IOUSBManagerDelegate
//
// This the protocol used by the delegate to recevie calls when a USB
// device has been added or removed.
//
//--------------------------------------------------------------------------

public typealias io_registry_id_t = UInt64

protocol USBManagerDelegate: class {
    func usbDeviceAdded(_   device: io_registry_id_t)
    func usbDeviceRemoved(_ device: io_registry_id_t)
}

//--------------------------------------------------------------------------
//
// MARK: - IOUSBManager class
//
//--------------------------------------------------------------------------

class USBManager {
    
    private let ioNotificationPort:   IONotificationPortRef
    
    private weak var delegate:      USBManagerDelegate?
    
    private var addedIterator:      io_iterator_t = 0
    private var removedIterator:    io_iterator_t = 0
    
    private let ioUSBManagerQueue:  DispatchQueue           = DispatchQueue(label: "com.getoffmyhack.waveSDR.IOUSBManagerQueue")
    private var matchingDict:       NSMutableDictionary     = IOServiceMatching(kIOUSBDeviceClassName)
    
    
    //--------------------------------------------------------------------------
    //
    // init() method to set up the notification port and dispatch queue
    //
    //--------------------------------------------------------------------------
    
    init() {
    
        // get the Master notificatin port for IO Kit
        let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
        guard notificationPort != nil else {
            fatalError("Unable to get IONotificationPort")
            
        }
        self.ioNotificationPort = notificationPort!
        
        // set up the dispatch queue for where the notifications will be sent
        IONotificationPortSetDispatchQueue(ioNotificationPort, ioUSBManagerQueue)
    
    }
    
    //--------------------------------------------------------------------------
    //
    // start()
    //
    // this method adds the matching notification.  The delegate is passed into
    // this fuction such that it is assured that the delegate has been set up
    // prior to any add/remove events being dispatched
    //
    //--------------------------------------------------------------------------
    
    func start(delegate: USBManagerDelegate) {

        // set the delegate object
        self.delegate = delegate
        
        // create callback closure for when a device is added
        let usbDeviceAddedCallback:IOServiceMatchingCallback = {
            (instance, iterator) in
                let usbManager = Unmanaged<USBManager>.fromOpaque(instance!).takeUnretainedValue()
                usbManager.usbDeviceAdded(iterator: iterator)
        }
        
        // create callback closure for when a device is removed
        let usbDeviceRemovedCallback: IOServiceMatchingCallback = {
            (instance, iterator) in
                let usbManager = Unmanaged<USBManager>.fromOpaque(instance!).takeUnretainedValue()
                usbManager.usbDeviceRemoved(iterator: iterator)
        }
        
        // create a pointer to this instace of USBManager
        let instancePointer = Unmanaged.passUnretained(self).toOpaque()
        
        // add notification for when a device is added
        IOServiceAddMatchingNotification(
            ioNotificationPort,
            kIOMatchedNotification,
            matchingDict,
            usbDeviceAddedCallback,
            instancePointer,
            &addedIterator
        )
        
        //Iterate over set of matching devices to access already-present devices
        //and to arm the notification
        self.usbDeviceAdded(iterator: addedIterator)

        // add notification for when a device is removed
        IOServiceAddMatchingNotification(
            ioNotificationPort,
            kIOTerminatedNotification,
            matchingDict,
            usbDeviceRemovedCallback,
            instancePointer,
            &removedIterator
        )
        
        //Iterate over set of matching devices to release each one and to
        //arm the notification
            self.usbDeviceRemoved(iterator: removedIterator)
        
    }
    
    //--------------------------------------------------------------------------
    //
    // deinit
    //
    // release all IOKit objects that have been created
    //
    //--------------------------------------------------------------------------
    
    deinit {
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(ioNotificationPort)
    }
    
    
    //--------------------------------------------------------------------------
    //
    // usbDeviceAdded
    //
    // called from the IOKit callback closure whenever a new USB device is added.
    // Each new device will create an USBDevice struct and pass to delegate
    //
    //--------------------------------------------------------------------------
    
    private func usbDeviceAdded(iterator: io_iterator_t) {
        
        // iterate through the list of devices from IOKit
        while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
            
            // call delegate with new device
            guard let delegate = self.delegate else {
                fatalError("No delegate for USBManager")
            }
            
            let registryID = device.ioRegistryID()
            IOObjectRelease(device)
            delegate.usbDeviceAdded(registryID)

            IOObjectRelease(device)
        }
        
    }
    
    //--------------------------------------------------------------------------
    //
    // usbDeviceRemoved
    //
    // called from the IOKit whenever a USB device is removed, calls delegate
    //
    //--------------------------------------------------------------------------
    
    private func usbDeviceRemoved(iterator: io_iterator_t) {
        
        // iterate through list of devices removed from IOKit
        while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {

            guard let delegate = self.delegate else {
                fatalError("No delegate for USBManager")
            }
            
            let registryID = device.ioRegistryID()
            IOObjectRelease(device)
            delegate.usbDeviceRemoved(registryID)
            
            IOObjectRelease(device)
   
        }
        
    }
    

    
}
