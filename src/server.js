/*jshint esversion: 6 */
"use strict";
// TODO Refactor into modules:
//      Framework part:
//      HID module: grabs recognized devices and listens to their output. Creates a Device with a unique id for each device that passes a recognizer
//      server module: communicates with a client, sends the products of the plugged-in transformer module to the client
//
//      User part:
//      Recognizers pair a predicate that takes a node-hid device, and a function that produces appropriate metadata for a Device. These are used to describe accepted device types. Users of the service order recognizers by specialization.
//      Transformers map device output data to some data format. Can be switched out, e.g. to produce DOM Events or something custom. Default is very thin.
//      injection happens through, say
//
//      InputServer.configure({
//          recognizers: recognizers, 
//          transformers: transformers,
//          clientURL: WEBSOCKET_PORT
//      });
//      InputServer.start();
//
//      or
//
//      let server = new InputServer({
//          recognizers: recognizers,
//          transformers: transformers,
//          clientURL: WEBSOCKET_PORT
//      });
//      server.start();
//
//      the InputServer internally has a workflow for deciding what DeviceDescriptors are stored in this.devices (via recognizers) and how data from those devices is transformed to be sent to the client (via transformers)
//      The missing part is how the InputServer associates metadata with the recognizers.
//      Sounds like a recognizer needs a metadata function as well.
//      Recognizer: {recognize: DeviceDescriptor => boolean, register: DeviceDescriptor => metadata};
//      Transformer: {recognize: metadata => boolean, transform: DeviceData => any};
//      So the inputserver has a loop going through recognizers where it says
//
//      if (rec.predicate(descriptor)) {
//          let device = HID.HID(descriptor.path);
//          let metadata = rec.registrar(descriptor);
//          let id = metadata.id;
//          this.devices[id] = {device: device, metadata: metadata};
//          device.on('data', this.transformAndSend(this.getTransformer(metadata)));
//      }
//
//      is the DeviceDescriptor sufficient as metadata?
//
//      With this level of complexity, I think it makes sense to make this a typescript project?
//      I don't have typings for node-hid though.
//
//
//
// Registers all plugged-in mice and sends their events through the configured web socket 
// FIXME: find out where to inject a strategy to handle different kinds of mice. the trackpad breaks the current assumptions about report format
//        make the mouse filter grab the apple trackpad.
//        and investigate why it is inconsistent about grabbing other devices.
// FIXME: The same device may appear in duplicate, and 
// I could feasibly have multiple of the same model device be plugged in at once.
// I can't distinguish between these two cases!
// A dialog system wouldn't fix this, because I don't think I have any way of actually determining whether two devices with the same vid and pid are different, unless there's a mount point field or something :-/
// There *may* be a serial number that will identify devices uniquely?
// Then I need to use a hash of the path as the id on the client end, rather than the vid + pid.
// Apparently one can also get devices by path, i.e. with 'device = new HID.HID(path)'
// TODO identify devices by path
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
 * */
var HID = require('../node_modules/node-hid');
var websocket_1 = require("websocket");
var http_1 = require("http");
var WEBSOCKET_PORT = 7777;
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
/*
const getAllDevices = function() {
    return HID.devices();
};

// TODO update when devices get plugged in/out?
let allDevices = getAllDevices();

let isMouse = (d) => d.usagePage === 1 && d.usage === 2;
let getDeviceId = (d) => `${d.vendorId}-${d.productId}`;

// Look for everything that looks like a mouse:
let mouseIds = Array.from(new Set(allDevices
    .filter(isMouse)
    .map(getDeviceId))) as string[];

let mice = {};

for (let mouseId of mouseIds) {
    let [vid, pid] = mouseId.split('-').map(parseInt) as [number, number]
    mice[mouseId] = new HID.HID(vid, pid);
}

let connection;

let socket = new server({
    httpServer: createServer().listen(WEBSOCKET_PORT)
});
console.log(`Waiting for socket connection on port ${WEBSOCKET_PORT}`);

socket.on("request", function(req) {
    connection = req.accept(null, req.origin);
    console.log("Socket connection opened");

    // send all registered mice to the client
    connection.sendUTF(JSON.stringify({ type: "deviceList", deviceList: Object.keys(mice) }));

    connection.on("message", function(msg) {
        //do we want any interaction?
        //Maybe for setting up mice interactively, i.e. asking the client to
        //click and move a mouse to give the client the corresponding vid and
        //pid.
        //Right now, I'm going with "all interaction can take place on the client side,
        //the server simply allows the client to start an abstract mouse for every mouse on startup.
    });

    connection.on("close", function(connection) {
        console.log("Socket connection closed");
    });
});

let devMouseChosen = false;
let developerMouse;

class Mouse {
    device: Device;
    deviceId: string;
    previousButtons: number;

    // TODO track devices by path rather than vid+pid
    constructor(device, id) {
        this.device = device;
        this.deviceId = id;

        this.previousButtons = 0;

        this.device.on('data', this.interpretMouseData.bind(this));
    }

    interpretMouseData(data) {
        if (!devMouseChosen) {
            console.log(`${this.deviceId} is the developer mouse.`);
            developerMouse = this.deviceId;
            this.device.close();
            devMouseChosen = true;
            return;
        }

        let processData = (data) => {
            if (data === undefined) return;
            let buttons = data[0];

            if (buttons !== this.previousButtons) {
                MouseButtonTransitionTable[`${this.previousButtons}`][`${buttons}`].map(
                    (result) => {
                        this.emitEvent(result.type, {buttons: buttons, button: result.button});
                    }
                );
            }

            this.previousButtons = buttons;

            let movedelta = [data[1], data[2]].map(x => x > 128 ? x - 256 : x);
            if (movedelta[0] !== 0 || movedelta[1] !== 0) {
                this.emitEvent("mousemove", { delta: movedelta });
            }
        }

        processData(data);
    }

    emitEvent(type, data) {
        console.log(type);

        if (!connection) {
            return;
        }

        let event = {
            type: type,
            data: data,
            deviceId: this.deviceId
        };

        connection.sendUTF(JSON.stringify(event));
        console.log(JSON.stringify(event));
    }
}

for (let mouseId in mice) {
    if (mouseId === '1452-631') continue;
    let mouse = mice[mouseId];
    new Mouse(mouse, mouseId);
}

console.log('Click a mouse to free it.');
*/
/* USER PART
 * Write custom recognizers and transformers to detect your supported devices and emit input data in your preferred format.
 */
/*
 * TODO recreate extant functionality in new framework format
 * How do I implement the developer  mouse trick with recognizers and transformers?
 * So far, I used a piece of global state shared among all the mice, which had their own behavior.
 * now there is no behavior in devices.
 * Since it is a hack of node-hid, I don't necessarily have to have a very good official way of supporting this.
 * What DOES need official support is some historical state associated with each device.
 * Probably in their metadata.
 * Otherwise, I can't support events, which work by comparing the previous state with the newest one.
 * So the mouseRecognizer
 *
 */
var mouseRecognizer = {
    recognize: function (desc) {
        return desc.usagePage === 1 && desc.usage === 2;
    },
    register: function (desc) {
        return {
            type: 'mouse',
            id: desc.path,
            developerMouseChosen: false
        };
    }
};
/*
Mouse data looks like this:
{
  "type": "Buffer",
  "data": [
    0, // button presses: 0 for all up, 1 for first down, 2 for second down, 3 for both down
    1, // x-axis: 1 for positive movement, 255 for negative movement
    255, // y-axis
    0, // scroll wheel
    0 // mystery!
  ]
}

*/
/* This table is used to create the 'button' field of browser mouse up and down events,
 * and to ensure that multiple events happen when there is an instantaneous transition from both buttons pressed to none pressed.
 * Lookups are done with the previous and current value of the buttons field in the mouse HID data,
 * which is the sum of the values of all currently pressed buttons.
 *
 * There's a good question of what sorts of guarantees I can present: Will a mouseup always be preceded by a corresponding mousedown?
 * What kind of variants should event-handling code be robust to? In my particular case,
 * I need to be able to accurately reflect the state of the mouse at all times.
 * For that purpose, the buttons sum is enough, since I can discern the state of the mouse from that without even tracking event type.
 *
 * */
var MouseButtonTransitionTable = {
    "0": {
        "1": [{ type: "mousedown", button: 0 }],
        "2": [{ type: "mousedown", button: 2 }],
        "3": [{ type: "mousedown", button: 0 }, { type: "mousedown", button: 2 }]
    },
    "1": {
        "0": [{ type: "mouseup", button: 0 }],
        "2": [{ type: "mouseup", button: 0 }, { type: "mousedown", button: 2 }],
        "3": [{ type: "mousedown", button: 2 }]
    },
    "2": {
        "0": [{ type: "mouseup", button: 2 }],
        "1": [{ type: "mouseup", button: 2 }, { type: "mousedown", button: 0 }],
        "3": [{ type: "mousedown", button: 0 }]
    },
    "3": {
        "0": [{ type: "mouseup", button: 0 }, { type: "mouseup", button: 2 }],
        "1": [{ type: "mouseup", button: 2 }],
        "2": [{ type: "mouseup", button: 0 }]
    }
};
var buttonMap = {
    0: [false, false, false],
    1: [true, false, false],
    2: [false, false, true],
    3: [true, false, true],
    4: [false, true, false],
    5: [true, true, false],
    6: [true, true, true]
};
var mouseDataTransformer = {
    recognize: function (metadata) {
        return metadata.type === 'mouse';
    },
    transform: function (data, metadata) {
        if (!metadata.developerMouseChosen && data[0] > 0) {
            console.log(metadata.id + " is the developer mouse.");
            // close the developer mouse and stop tracking it
            this.devices[metadata.id].device.close();
            delete this.devices[metadata.id];
            // update all mice to indicate that the developer mouse has been chosen
            for (var id in this.devices) {
                var metadata_2 = this.devices[id].metadata;
                if (metadata_2.type === 'mouse') {
                    metadata_2.developerMouseChosen = true;
                }
            }
            // do not send this result
            return false;
        }
        var result = {};
        var buttons = buttonMap[data[0]];
        result['left'] = buttons[0];
        result['middle'] = buttons[1];
        result['right'] = buttons[2];
        var movedelta = [data[1], data[2]].map(function (n) { return n > 128 ? n - 256 : n; });
        result['dx'] = movedelta[0];
        result['dy'] = movedelta[1];
        result['scroll'] = data[3];
        result['id'] = metadata.id;
        return result;
    }
};
// TODO a specialized recognizer for the apple trackpad and transformer
var inputServer = new InputServer({
    clientURL: WEBSOCKET_PORT,
    recognizers: [mouseRecognizer],
    transformers: [mouseDataTransformer]
});
inputServer.connect();
