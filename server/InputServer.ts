// TODO: Detect when devices are plugged in or out, and send corresponding messages to the client.
//       TODO: create a single point that manages the client messaging part of adding and removing devices,
//             i.e. initial registration should happen by the same mechanism that continuous adding does.

// Possible TODO: a dialogical system where the client creates sample input events to grab a specific mouse. 
// This could be helpful in several respects: 
//   I wouldn't have to rely on the inconsistent filtering code, 
//   I could theoretically make virtual mice that aren't strictly bound to single mice
//   This feels like it should be client-end, though.

// FIXME: Allow mice to be used regularly while the server is in effect
//        It's unclear whether or not this is a bug.
//        I've played around with using the API in different ways.
//        This has the exact same result as using device.on(), i.e. it keeps holding on to the device.
//        If I open and close rather than resume and pause, the processing function is called, but data is always undefined -_-
//        I have instituted a workaround: prompt for a click by the 'developer' mouse on startup and close that device.

/* FRAMEWORK PART
 * Manages recognizing and registering devices, and sending their data to the client.
 * Extend the server with support for your devices and input data format in ./main.ts
 * */
const HID = require('../node_modules/node-hid') as NodeHID;
const usbDetect = require('../node_modules/usb-detection') as USBDetection;
import {server} from 'websocket';
import {createServer} from 'http';

interface NodeHID {
    devices: () => DeviceDescriptor[];
    HID: DeviceConstructor;
}

export interface DeviceDescriptor {
    vendorId    : number;
    productId   : number;
    path        : string;
    release     : number;
    'interface' : number;
    usagePage   : number;
    usage       : number;
    serialNumber: string;
    manufacturer: string;
    product     : string;
}

interface DeviceConstructor {
    new(vid: number, pid: number): Device;
    new(path: string): Device;
}

interface Device {
    // this is a bad type signature, but I'm not sure how to wrangle typescript into a better one
    on: (eventType: 'data' | 'error', callback: (dataOrError: DeviceData | Error) => void) => void;
    close: () => void;
}

export interface DeviceData {
    type: string;
    data: number[];
}

interface USBDetection {
    on: (eventName: string, callback: (device: USBDetectionDevice) => void) => void;
        /* eventName can be:
         *   add (also aliased as insert)
         *   add:vid
         *   add:vid:pid
         *   remove
         *   remove:vid
         *   remove:vid:pid
         *   change
         *   change:vid
         *   change:vid:pid
         */
    startMonitoring: () => void;
    stopMonitoring: () => void;
}

interface USBDetectionDevice {
	locationId   : number;
	vendorId     : number;
	productId    : number;
	deviceAddress: number;
	deviceName   : string;
	manufacturer : string;
	serialNumber : string;
}

export interface Recognizer {
    recognize: (desc: DeviceDescriptor) => boolean;
    register: (desc: DeviceDescriptor) => any;
};

export interface Transformer {
    recognize: (metadata: any) => boolean;
    transform: (input: DeviceData, metadata: any) => any;
};

interface DeviceRecord {
    desc    : DeviceDescriptor;
    device  : Device; 
    metadata: any;
}

interface DeviceRegistry {
    [key: string]: DeviceRecord;
}

//   FIXME: since both device finding functions match by vendorId and productId, they assume that only one such device is plugged in.
//   I use them to bridge from USBDetectionDevice to node-hid's DeviceDescriptor
//   It would be ideal if both libraries specified path, but even then, it doesn't have a standard format that I could match.
//   I can't assume that I have access to serial number, as it seems to be priviledged information on unix systems.

// node-hid can't always find a device right after it is plugged in.
// I think sleep reduces the chance of that error occurring.
// do nothing for napTime milliseconds
const sleep = function(napTime: number) {
    let start = Date.now();
    while (true) {
        if (Date.now() - start >= napTime) {
            return;
        }
    }
}

interface InputServerConfig {
    clientURL    : number;
    transformers : Transformer[];
    recognizers  : Recognizer[];
    [key: string]: any; // this is for any additional values one wants to store in the InputServer, e.g. flags for various cross-device state
}

export class InputServer {
    clientURL   : number;
    transformers: Transformer[];
    recognizers : Recognizer[];
    devices     : DeviceRegistry = {};
    connection  : any; // @types/websocket does not export the connection type, but I would like to track it across methods :-/

    constructor(config: InputServerConfig) {
        for (let key in config) {
            this[key] = config[key];
        }

        this.registerDevices();

        usbDetect.startMonitoring();
        usbDetect.on('add', this.addDevice.bind(this));
        usbDetect.on('remove', this.removeDevice.bind(this));
    }

    // look for a device that's plugged in but not registered with the InputServer
    findUnregisteredDevice(vendorId: number, productId: number): DeviceDescriptor {
        for (let desc of HID.devices()) {
            if (desc.vendorId === vendorId && desc.productId === productId) {
                return desc;
            }
        }
        throw new Error(`Cannot find unregistered device with vendorId ${vendorId} and productId ${productId}`);
    }

    // look for a device registered with the InputServer
    findRegisteredDevice(vendorId: number, productId: number): DeviceRecord {
        for (let id in this.devices) {
            let record = this.devices[id];
            if (record.desc.vendorId === vendorId && record.desc.productId === productId) {
                return record;
            }
        }
        throw new Error(`Cannot find registered device with vendorId ${vendorId} and productId ${productId}`);
    }

    // fill up this.devices
    registerDevices() {
        let allDeviceDescriptors = HID.devices();

        for (let desc of allDeviceDescriptors) {
            this.registerDevice(desc);
        }
    }

    registerDevice(desc) {
        // apply recognizers in order
        for (let rec of this.recognizers) {
            if (rec.recognize(desc)) {
                let device = new HID.HID(desc.path);
                let metadata = rec.register(desc);
                let id = metadata.id;
                this.devices[id] = {
                    desc    : desc,
                    device  : device,
                    metadata: metadata
                };

                let sendAndTransform = function(data: DeviceData) {
                    let transform = this.getTransformer(metadata);
                    let transformed = transform(data, metadata);
                    if (transformed) {
                        this.sendToClient(transformed);
                    }
                }

                let handleError = function(err: Error) {
                    /* throw out the device? 
                     * Interesting situation: an error will be provoked on plugout, but removeDevice is called
                     * TODO: Figure out if anything should be done here.
                     * */
                    console.log('Not handling error');
                }

                device.on('data', sendAndTransform.bind(this));
                device.on('error', handleError);

                return;
            }
        }
    }

    getTransformer(metadata: any): (data: DeviceData) => any {
        for (let trans of this.transformers) {
            if (trans.recognize(metadata)) {
                return trans.transform.bind(this);
            }
        }

        throw new Error(`No transformer found for device with metadata ${JSON.stringify(metadata)}`);
    }

    // method called when a device is plugged in while the InputServer is operating
    addDevice(usbDevice: USBDetectionDevice) {
        console.log('Device plugged in');

        let [vid, pid] = [usbDevice.vendorId, usbDevice.productId];
        sleep(100);
        let desc = this.findUnregisteredDevice(vid, pid);
        this.registerDevice(desc);
    }

    // method called when a device is removed while the InputServer is operating
    removeDevice(usbDevice: USBDetectionDevice) {
        console.log('Device removed');

        let [vid, pid] = [usbDevice.vendorId, usbDevice.productId];
        let record = this.findRegisteredDevice(vid, pid);
        let id = record.metadata.id;
        this.devices[id].device.close();
        delete this.devices[id];
    }

    connect() {
        let socket = new server({
            httpServer: createServer().listen(this.clientURL)
        });
        console.log(`Waiting for socket connection on port ${this.clientURL}`);

        socket.on('request', function(req) {
            this.connection = req.accept(null, req.origin);
            console.log('Socket connection opened');

            let deviceIds = Object.keys(this.devices);
            this.connection.sendUTF(JSON.stringify({ type: 'deviceList', deviceList: deviceIds }));

            /*
            connection.on('message', function(msg) {
            });
            */

            this.connection.on('close', function(connection) {
                console.log('Socket connection closed');
            });
        });
    }

    sendToClient(transformedData: any) {
        console.log('Sending input data to client.');

        if (!this.connection) {
            return;
        }

        this.connection.sendUTF(JSON.stringify(transformedData));
    }
}
