// TODO: Detect when devices are plugged in or out, and send corresponding messages to the client.

// Possible TODO: a dialogical system where the client creates sample input events to grab a specific mouse. 
// This could be helpful in several respects: 
//   I wouldn't have to rely on the inconsistent filtering code, 
//   I could theoretically make virtual mice that aren't strictly bound to single mice

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
    vendorId: number;
    productId: number;
    path: string;
    serialNumber: string;
    manufacturer: string;
    product: string;
    release: number;
    'interface': number;
    usagePage: number;
    usage: number;
}

interface DeviceConstructor {
    new(vid: number, pid: number): Device;
    new(path: string): Device;
}

interface Device {
    on: (eventType: string, callback: (data: DeviceData) => void) => void;
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
	locationId: number;
	vendorId: number;
	productId: number;
	deviceName: string;
	manufacturer: string;
	serialNumber: string;
	deviceAddress: number;
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
    [key: string]: {device: Device, metadata: any};
}

export class InputServer {
    clientURL: number;
    transformers: Transformer[];
    recognizers: Recognizer[];
    devices: DeviceRecord = {};
    connection: any; // @types/websocket does not export the connection type, but I would like to track it across methods :-/

    constructor(config: {
        clientURL: number,
        transformers: Transformer[],
        recognizers: Recognizer[]
    }) {
        this.clientURL = config.clientURL;
        this.transformers = config.transformers;
        this.recognizers = config.recognizers;

        this.registerDevices();
    }

    // fill up this.devices
    registerDevices() {
        let allDeviceDescriptors = HID.devices();

        for (let desc of allDeviceDescriptors) {
            // apply recognizers in order
            for (let rec of this.recognizers) {
                if (rec.recognize(desc)) {
                    let device = new HID.HID(desc.path);
                    let metadata = rec.register(desc);
                    let id = metadata.id;
                    this.devices[id] = {
                        device: device,
                        metadata: metadata
                    };

                    let sendAndTransform = function(data: DeviceData) {
                        let transform = this.getTransformer(metadata);
                        let transformed = transform(data, metadata);
                        if (transformed) {
                            this.sendToClient(transformed);
                        }
                    }

                    device.on('data', sendAndTransform.bind(this));

                    break;
                }
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
