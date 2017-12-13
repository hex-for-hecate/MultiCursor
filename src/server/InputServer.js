/*
 * Manages recognizing and registering devices, and sending their data to the client.
 * Extend the server with support for your devices and input data format in ./main.ts
 * */
"use strict";
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
var HID = require('../node_modules/node-hid');
var usbDetect = require('../node_modules/usb-detection');
var websocket_1 = require("websocket");
var http_1 = require("http");
;
;
// node-hid can't always find a device right after it is plugged in.
// I think sleep reduces the chance of that error occurring.
// do nothing for napTime milliseconds
var sleep = function (napTime) {
    var start = Date.now();
    while (true) {
        if (Date.now() - start >= napTime) {
            return;
        }
    }
};
var InputServer = (function () {
    function InputServer(config) {
        this.devices = {};
        for (var key in config) {
            this[key] = config[key];
        }
        this.registerDevices();
        usbDetect.startMonitoring();
        usbDetect.on('add', this.addDevice.bind(this));
        usbDetect.on('remove', this.removeDevice.bind(this));
    }
    // look for a device that's plugged in but not registered with the InputServer
    InputServer.prototype.findUnregisteredDevice = function (vendorId, productId) {
        for (var _i = 0, _a = HID.devices(); _i < _a.length; _i++) {
            var desc = _a[_i];
            if (desc.vendorId === vendorId && desc.productId === productId) {
                return desc;
            }
        }
        throw new Error("Cannot find unregistered device with vendorId " + vendorId + " and productId " + productId);
    };
    // look for a device registered with the InputServer
    InputServer.prototype.findRegisteredDevice = function (vendorId, productId) {
        for (var id in this.devices) {
            var record = this.devices[id];
            if (record.desc.vendorId === vendorId && record.desc.productId === productId) {
                return record;
            }
        }
        throw new Error("Cannot find registered device with vendorId " + vendorId + " and productId " + productId);
    };
    // fill up this.devices
    InputServer.prototype.registerDevices = function () {
        var allDeviceDescriptors = HID.devices();
        for (var _i = 0, allDeviceDescriptors_1 = allDeviceDescriptors; _i < allDeviceDescriptors_1.length; _i++) {
            var desc = allDeviceDescriptors_1[_i];
            this.registerDevice(desc);
        }
    };
    InputServer.prototype.registerDevice = function (desc) {
        var _loop_1 = function (rec) {
            if (rec.recognize(desc)) {
                var device = new HID.HID(desc.path);
                var metadata_1 = rec.register(desc);
                var id = metadata_1.id;
                this_1.devices[id] = {
                    desc: desc,
                    device: device,
                    metadata: metadata_1
                };
                var transformAndSend = function (data) {
                    var transform = this.getTransformer(metadata_1);
                    var transformed = transform(data, metadata_1);
                    if (transformed) {
                        this.sendToClient(transformed);
                    }
                };
                var handleError = function (err) {
                    /*
                     * TODO: Figure out if anything should be done here.
                     * */
                    console.log('Not handling error');
                };
                device.on('data', transformAndSend.bind(this_1));
                device.on('error', handleError);
                if (!this_1.connection) {
                    return { value: void 0 };
                }
                else {
                    this_1.connection.sendUTF(JSON.stringify({
                        type: 'addDevice',
                        device: {
                            type: metadata_1.clientType,
                            id: metadata_1.id
                        }
                    }));
                }
            }
        };
        var this_1 = this;
        // apply recognizers in order
        for (var _i = 0, _a = this.recognizers; _i < _a.length; _i++) {
            var rec = _a[_i];
            var state_1 = _loop_1(rec);
            if (typeof state_1 === "object")
                return state_1.value;
        }
    };
    InputServer.prototype.unregisterDevice = function (id) {
        //TODO this is to be called from removeDevice and from the routine that chooses the devleloper mosue
        this.devices[id].device.close();
        delete this.devices[id];
        if (!this.connection) {
            return;
        }
        else {
            // for removal, the client side only needs the id, since it is expected to maintain all the other metadata by association with the id
            this.connection.sendUTF(JSON.stringify({
                type: 'removeDevice',
                device: {
                    id: id
                }
            }));
        }
    };
    InputServer.prototype.getTransformer = function (metadata) {
        for (var _i = 0, _a = this.transformers; _i < _a.length; _i++) {
            var trans = _a[_i];
            if (trans.recognize(metadata)) {
                return trans.transform.bind(this);
            }
        }
        throw new Error("No transformer found for device with metadata " + JSON.stringify(metadata));
    };
    // method called when a device is plugged in while the InputServer is operating
    InputServer.prototype.addDevice = function (usbDevice) {
        console.log('Device plugged in');
        var _a = [usbDevice.vendorId, usbDevice.productId], vid = _a[0], pid = _a[1];
        sleep(100);
        var desc = this.findUnregisteredDevice(vid, pid);
        this.registerDevice(desc);
    };
    // method called when a device is removed while the InputServer is operating
    InputServer.prototype.removeDevice = function (usbDevice) {
        console.log('Device removed');
        var _a = [usbDevice.vendorId, usbDevice.productId], vid = _a[0], pid = _a[1];
        var record = this.findRegisteredDevice(vid, pid);
        var id = record.metadata.id;
        this.unregisterDevice(id);
    };
    InputServer.prototype.connect = function () {
        var self = this;
        var socket = new websocket_1.server({
            httpServer: http_1.createServer().listen(self.clientURL)
        });
        console.log("Waiting for socket connection on port " + self.clientURL);
        socket.on('request', function (req) {
            self.connection = req.accept(null, req.origin);
            console.log('Socket connection opened');
            var deviceMetadata = Object.keys(self.devices).map(function (key) { return ({
                id: self.devices[key].metadata.id,
                type: self.devices[key].metadata.clientType
            }); });
            self.connection.sendUTF(JSON.stringify({
                type: 'addDevices',
                deviceList: deviceMetadata
            }));
            /*
            connection.on('message', function(msg) {
            });
            */
            self.connection.on('close', function (connection) {
                console.log('Socket connection closed');
            });
        });
    };
    InputServer.prototype.sendToClient = function (transformedData) {
        console.log('Sending input data to client.');
        if (!this.connection) {
            return;
        }
        this.connection.sendUTF(JSON.stringify(transformedData));
    };
    return InputServer;
}());
exports.InputServer = InputServer;
