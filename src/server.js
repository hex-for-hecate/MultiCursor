/*jshint esversion: 6 */

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

const HID = require('../node_modules/node-hid');
const server = require('websocket').server, http = require('http');

const WEBSOCKET_PORT = 7777;

const getAllDevices = function() {
    return HID.devices();
};

// TODO update when devices get plugged in/out?
let allDevices = getAllDevices();

// Look for everything that looks like a mouse:
let mouseIds = Array.from(new Set(allDevices
    .filter((d) => d.usagePage === 1 && d.usage === 2)
    .map((d) => `${d.vendorId}-${d.productId}`)));

let mice = {};

for (let mouseId of mouseIds) {
    mice[mouseId] = new HID.HID(...mouseId.split('-'));
}

let connection;

let socket = new server({
    httpServer: http.createServer().listen(WEBSOCKET_PORT)
});
console.log(`Waiting for socket connection on port ${WEBSOCKET_PORT}`);

socket.on("request", function(req) {
    connection = req.accept(null, req.origin);
    console.log("Socket connection opened");

    // send all registered mice to the client
    connection.sendUTF(JSON.stringify({ type: "deviceList", deviceList: mice }));

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
const MouseButtonTransitionTable = {
    "0": {
        "1": [{type: "mousedown", button: 0}],
        "2": [{type: "mousedown", button: 2}],
        "3": [{type: "mousedown", button: 0}, {type: "mousedown", button: 2}]
    },
    "1": {
        "0": [{type: "mouseup", button: 0}],
        "2": [{type: "mouseup", button: 0}, {type: "mousedown", button: 2}],
        "3": [{type: "mousedown", button: 2}]
    },
    "2": {
        "0": [{type: "mouseup", button: 2}],
        "1": [{type: "mouseup", button: 2}, {type: "mousedown", button: 0}],
        "3": [{type: "mousedown", button: 0}]
    },
    "3": {
        "0": [{type: "mouseup", button: 0}, {type: "mouseup", button: 2}],
        "1": [{type: "mouseup", button: 2}],
        "2": [{type: "mouseup", button: 0}]
    }
};

let devMouseChosen = false;
let developerMouse;

class Mouse {
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
