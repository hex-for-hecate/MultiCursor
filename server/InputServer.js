// Possible TODO: a dialogical system where the client creates sample input events to grab a specific mouse. 
// This could be helpful in several respects: 
//   I wouldn't have to rely on the inconsistent filtering code, 
//   I could theoretically make virtual mice that aren't strictly bound to single mice
"use strict";
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
var HID = require('../node_modules/node-hid');
var websocket_1 = require("websocket");
var http_1 = require("http");
;
;
var InputServer = (function () {
    function InputServer(config) {
        this.devices = {};
        this.clientURL = config.clientURL;
        this.transformers = config.transformers;
        this.recognizers = config.recognizers;
        this.registerDevices();
    }
    // fill up this.devices
    InputServer.prototype.registerDevices = function () {
        var allDeviceDescriptors = HID.devices();
        for (var _i = 0, allDeviceDescriptors_1 = allDeviceDescriptors; _i < allDeviceDescriptors_1.length; _i++) {
            var desc = allDeviceDescriptors_1[_i];
            var _loop_1 = function (rec) {
                if (rec.recognize(desc)) {
                    var device = new HID.HID(desc.path);
                    var metadata_1 = rec.register(desc);
                    var id = metadata_1.id;
                    this_1.devices[id] = {
                        device: device,
                        metadata: metadata_1
                    };
                    var sendAndTransform = function (data) {
                        var transform = this.getTransformer(metadata_1);
                        var transformed = transform(data, metadata_1);
                        if (transformed) {
                            this.sendToClient(transformed);
                        }
                    };
                    device.on('data', sendAndTransform.bind(this_1));
                    return "break";
                }
            };
            var this_1 = this;
            // apply recognizers in order
            for (var _a = 0, _b = this.recognizers; _a < _b.length; _a++) {
                var rec = _b[_a];
                var state_1 = _loop_1(rec);
                if (state_1 === "break")
                    break;
            }
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
    InputServer.prototype.connect = function () {
        var socket = new websocket_1.server({
            httpServer: http_1.createServer().listen(this.clientURL)
        });
        console.log("Waiting for socket connection on port " + this.clientURL);
        socket.on('request', function (req) {
            this.connection = req.accept(null, req.origin);
            console.log('Socket connection opened');
            var deviceIds = Object.keys(this.devices);
            this.connection.sendUTF(JSON.stringify({ type: 'deviceList', deviceList: deviceIds }));
            /*
            connection.on('message', function(msg) {
            });
            */
            this.connection.on('close', function (connection) {
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
