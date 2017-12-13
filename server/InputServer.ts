/* 
 * Manages recognizing and registering devices, and sending their data to the client.
 * Extend the server with support for your devices and input data format in ./main.ts
 * */

/*
 * FIXME: Allow mice to be used regularly while the server is in effect
 *        It's unclear whether or not this is a bug.
 *        On Michel's suggestion, I have instituted a workaround: prompt for a click by the 'developer' mouse on startup and close that device.
 *
 * TODO Work out the right way to create device identifiers.
 * Since the association between an id and a device is stored in the callbacks attached to each device, I strictly speaking don't have to make it a hash of the path. Making it a hash of path should make the same device plugged into the same (series of) port(s) get the same id consistently, but what would be really useful would be to be able to recognize devices uniquely regardless of how where they are plugged in, i.e., to be able to move a mouse between computers and maintain some specialized behavior. 
 * To be fair, using vid and pid _does_ uniquely identify the product, if not the specific device.
 * That would probably be better in most operating circumstances.
 * Is there some way to make path be the distinguishing factor in case of a vid+pid overlap?
 *
 * FIXME One of the side effects of not being able to distinguish between two devices with the same vid-pid pair is that I lose the ability to unambiguously bridge from a device descriptor given by usb-detection to one given by node-hid in that specific case.
 */

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

                let transformAndSend = function(data: DeviceData) {
                    let transform = this.getTransformer(metadata);
                    let transformed = transform(data, metadata);
                    if (transformed) {
                        this.sendToClient(transformed);
                    }
                }

                let handleError = function(err: Error) {
                    /*
                     * TODO: Figure out if anything should be done here.
                     * */
                    console.log('Not handling error');
                }

                device.on('data', transformAndSend.bind(this));
                device.on('error', handleError);

                if (!this.connection) {
                    return;
                } else {
                    this.connection.sendUTF(JSON.stringify({ 
                        type: 'addDevice', 
                        device: {
                            type: metadata.clientType,
                            id: metadata.id
                        }
                    }));
                }
            }
        }
    }

    unregisterDevice(id) {
        //TODO this is to be called from removeDevice and from the routine that chooses the devleloper mosue
        
        this.devices[id].device.close();
        delete this.devices[id];

        if (!this.connection) {
            return;
        } else {
            // for removal, the client side only needs the id, since it is expected to maintain all the other metadata by association with the id
            this.connection.sendUTF(JSON.stringify({ 
                type: 'removeDevice', 
                device: {
                    id: id
                }
            }));
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
        this.unregisterDevice(id);
    }

    connect() {
        let self = this;

        let socket = new server({
            httpServer: createServer().listen(self.clientURL)
        });
        console.log(`Waiting for socket connection on port ${self.clientURL}`);

        socket.on('request', function(req) {
            self.connection = req.accept(null, req.origin);
            console.log('Socket connection opened');

            let deviceMetadata = Object.keys(self.devices).map((key) => ({
                id: self.devices[key].metadata.id,
                type: self.devices[key].metadata.clientType
            }));
            self.connection.sendUTF(JSON.stringify({ 
                type: 'addDevices', 
                deviceList: deviceMetadata 
            }));

            /*
            connection.on('message', function(msg) {
            });
            */

            self.connection.on('close', function(connection) {
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
