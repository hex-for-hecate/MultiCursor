/*jshint esversion: 6 */
// Registers all plugged-in mice and sends their events through the configured web socket (TODO)

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

let connection;

let socket = new server({
    httpServer: http.createServer().listen(7777)
});

socket.on("request", function(req) {
    connection = req.accept(null, req.origin);
    console.log("Socket connection opened");

    connection.on("message", function(msg) {
        //do we want any interaction?
        //Maybe for setting up mice interactively, i.e. asking the client to
        //click and move a mouse to give the client the corresponding vid and
        //pid.
    });

    connection.on("close", function(connection) {
        console.log("Socket connection closed");
    });
});

const getAllDevices = function() {
    return HID.devices();
};

// TODO update when devices get plugged in/out?
let allDevices = getAllDevices();

class Mouse {
    constructor(vid, pid) {
        this.deviceId =  `${vid}-${pid}`;
        let device = new HID.HID(vid, pid);
        device.on("data", this.interpretMouseData.bind(this));
    }

    interpretMouseData(data) {
        var button = data[0];
        if (button > this.button) {
            this.emitEvent("mousedown", { button: button });
        } else if (button < this.button) {
            this.emitEvent("mouseup", { button: button });
        }
        this.button = button;

        // TODO fix delta function 
        let movedelta = [data[1], data[2]].map(x => x === 255 ? -1 : x);
        if (movedelta[0] !== 0 || movedelta[1] !== 0) {
            this.emitEvent("mousemove", { delta: movedelta }); 
        }
    }

    emitEvent(type, data) {
        if (!connection) {
            console.log(`Sending ${type} event`);
            return;
        }

        let event = { 
            type: type,
            data: data,
            deviceId: this.deviceId
        };

        connection.sendUTF(JSON.stringify(event));
    }
}

// start sending events for a particular mouse
let mouse = new Mouse(1133, 49232);

