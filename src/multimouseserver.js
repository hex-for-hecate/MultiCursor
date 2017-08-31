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

I'll need to do something where I look at changes to log events I guess?
Like, mouseup is when the 0 is smaller than it was before,
mousedown is when the 0 is bigger than before,
mousemove is when either of 1 and 2 change to something that's not 0
*/

const HID = require('../node_modules/node-hid');
const util = require('util');
const events = require('events');

const getAllDevices = function() {
    return HID.devices();
}

let allDevices = getAllDevices();

//util.inherits(PowerMate, events.EventEmitter);

class Mouse {
    constructor(vid, pid) {
        this.vid = vid;
        this.pid = pid;
        let device = new HID.HID(vid, pid);
        device.on("data", this.interpretMouseData);
    }

    interpretMouseData(data) {
        var button = data[0];
        if (button > this.button) {
            //this.emit mousedown
        } else if (button < this.button) {
            //this.emit mouseup
        }
        this.button = button;
        var delta = [data[1], data[2]].map(x => x === 255 ? -1 : x);
        if (delta[0] !== 0 || delta[1] !== 0) {
            //this.emit mousemove
        }
    }

    emitEvent(type, data) {
    }
}
let mouse = new Mouse(1133, 49232);

