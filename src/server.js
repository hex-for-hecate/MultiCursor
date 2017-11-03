/*jshint esversion: 6 */

// Registers all plugged-in mice and sends their events through the configured web socket 
// FIXME: make the mouse filter grab the apple trackpad.
//        and investigate why it is inconsistent about grabbing other devices.

// FIXME: The same device may appear in duplicate, and 
// I could feasibly have multiple of the same model device be plugged in at once.
// I can't distinguish between these two cases!
// A dialog system wouldn't fix this, because I don't think I have any way of actually determining whether two devices with the same vid and pid are different, unless there's a mount point field or something :-/
// There *may* be a serial number that will identify devices uniquely?
// Apparently one can also get devices by path, i.e. with 'device = new HID.HID(path)'
// Then I need to use a hash of the path as the id on the client end, rather than the vid + pid.

// Possible TODO: a dialogical system where the client creates sample input events to grab a specific mouse. 
// This could be helpful in several respects: 
//   I wouldn't have to rely on the inconsistent filtering code, 
//   I could theoretically make virtual mice that aren't strictly bound to single mice
//   
//

// FIXME: Allow mice to be used regularly while the server is in effect
//        Turns out the undocumented device.setNonBlocking(1) is not the solution.
//        It just causes the data callback to be called continuously, while still locking down devices.
//        It's possible I just need to decide to sample devices with some frequency via device.read().

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


where am I going to sum to position? 
On the client side, a Mouse object will keep a position. 
Since the client will have a local event emitter anyway, there's no good argument for me laying special semantics on mice here.

*/

const HID = require('../node_modules/node-hid');
const server = require('websocket').server, http = require('http');

const getAllDevices = function() {
    return HID.devices();
};

// TODO update when devices get plugged in/out?
let allDevices = getAllDevices();
let devices = HID.devices();

// Look for everything that looks like a mouse:
let mice = Array.from(new Set(allDevices
    .filter((d) => d.usagePage === 1 && d.usage === 2)
    .map((d) => `${d.vendorId}-${d.productId}`)));

let connection;

let socket = new server({
    httpServer: http.createServer().listen(7777)
});

socket.on("request", function(req) {
    connection = req.accept(null, req.origin);
    console.log("Socket connection opened");

    // send all registered mice to the client
    connection.sendUTF(JSON.stringify({ type: "devicelist", devicelist: mice }));

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

class Mouse {
    constructor(vid, pid) {
        this.deviceId =  `${vid}-${pid}`;
        let device = new HID.HID(vid, pid);
        device.on("data", this.interpretMouseData.bind(this));
        this.previousButtons = 0;
    }

    interpretMouseData(data) {
        let buttons = data[0];
        if (buttons === undefined) return;

        if (buttons !== this.previousButtons) {
            MouseButtonTransitionTable[`${this.previousButtons}`][`${buttons}`].map(
                (result) => { this.emitEvent(result.type, {buttons: buttons, button: result.button}); }
            );
        }

        this.previousButtons = buttons;

        let movedelta = [data[1], data[2]].map(x => x > 128 ? x - 256 : x);
        if (movedelta[0] !== 0 || movedelta[1] !== 0) {
            this.emitEvent("mousemove", { delta: movedelta }); 
        }
    }

    emitEvent(type, data) {
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

// Start sending events for all mice
for (let mouse of mice) {
    let [vid, pid] = mouse.split("-");
    console.log(vid, pid);
    new Mouse(vid, pid);
}

