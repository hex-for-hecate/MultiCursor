"use strict";
var InputServer_1 = require("./InputServer");
/* Configure and run the Input Server for your particular devices and client device abstraction.
 *
 * TODO proof-of-concept code for generating DOM Events to show general usability of the InputServer
 */
var WEBSOCKET_PORT = 7777;
var generateDeviceId = function (desc) {
    //return desc.path.split(' ').join('');
    return "device-" + desc.vendorId + "-" + desc.productId;
};
var mouseRecognizer = {
    recognize: function (desc) {
        var matched = desc.usagePage === 1 && desc.usage === 2;
        if (matched) {
            console.log("Recognized mouse with vendorId:productId " + desc.vendorId + ":" + desc.productId);
        }
        return matched;
    },
    register: function (desc) {
        return {
            serverType: 'mouse',
            clientType: 'mouse',
            id: generateDeviceId(desc)
        };
    }
};
var trackballRecognizer = {
    recognize: function (desc) {
        var matched = desc.vendorId === 1149 && desc.productId === 4099;
        if (matched) {
            console.log("Recognized Kensington Trackball.");
        }
        return matched;
    },
    register: function (desc) {
        return {
            serverType: 'trackball',
            clientType: 'mouse',
            id: generateDeviceId(desc)
        };
    }
};
var mbpTrackpadRecognizer = {
    recognize: function (desc) {
        var matched = desc.vendorId === 1452 && desc.productId === 631 && desc.usagePage === 1 && desc.usage === 2;
        if (matched) {
            console.log("Recognized macbook pro trackpad.");
        }
        return matched;
    },
    register: function (desc) {
        return {
            serverType: 'mbpTrackpad',
            clientType: 'mouse',
            id: generateDeviceId(desc)
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

except sometimes it's a trackball and it has no scroll, and sometimes it's a trackpad and has more mystery fields.
Device data can be addressed as an array directly.

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
// maps mouse button codes to the states of the left, middle, and right buttons
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
        return metadata.serverType === 'mouse';
    },
    transform: function (data, metadata) {
        // pretty print data
        //console.log('mouse transformer');
        //console.log(JSON.stringify(data, null, 2));
        if (!this.developerMouseChosen && data[0] > 0) {
            console.log(metadata.id + " is the developer mouse.");
            // close the developer mouse and stop tracking it
            this.unregisterDevice(metadata.id);
            this.developerMouseChosen = true;
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
        result['metadata'] = {
            type: metadata.clientType,
            id: metadata.id
        };
        result['type'] = 'input';
        return result;
    }
};
var trackballDataTransformer = {
    recognize: function (metadata) {
        return metadata.serverType === 'trackball';
    },
    transform: function (data, metadata) {
        // pretty print data
        //console.log('trackball transformer');
        //console.log(JSON.stringify(data, null, 2));
        if (!this.developerMouseChosen && data[0] > 0) {
            console.log(metadata.id + " is the developer mouse.");
            // close the developer mouse and stop tracking it
            this.unregisterDevice(metadata.id);
            this.developerMouseChosen = true;
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
        result['scroll'] = 0;
        result['type'] = 'input';
        result['metadata'] = {
            type: metadata.clientType,
            id: metadata.id
        };
        return result;
    }
};
var mbpTrackpadDataTransformer = {
    recognize: function (metadata) {
        return metadata.serverType === 'mbpTrackpad';
    },
    transform: function (data, metadata) {
        // pretty print data
        //console.log('trackpad transformer');
        //console.log(JSON.stringify(data, null, 2));
        if (!this.developerMouseChosen && data[1] > 0) {
            console.log(metadata.id + " is the developer mouse.");
            // close the developer mouse and stop tracking it
            this.unregisterDevice(metadata.id);
            this.developerMouseChosen = true;
            // do not send this result
            return false;
        }
        // in this transformer, we produce data structured like that of the normal mouse 
        var result = {};
        var buttons = buttonMap[data[1]];
        result['left'] = buttons[0];
        result['middle'] = buttons[1];
        result['right'] = buttons[2];
        var movedelta = [data[2], data[3]].map(function (n) { return n > 128 ? n - 256 : n; });
        result['dx'] = movedelta[0];
        result['dy'] = movedelta[1];
        result['scroll'] = 0;
        result['type'] = 'input';
        result['metadata'] = {
            type: metadata.clientType,
            id: metadata.id
        };
        return result;
    }
};
var inputServer = new InputServer_1.InputServer({
    clientURL: WEBSOCKET_PORT,
    recognizers: [mbpTrackpadRecognizer, trackballRecognizer, mouseRecognizer],
    transformers: [mbpTrackpadDataTransformer, trackballDataTransformer, mouseDataTransformer],
    developerMouseChosen: false
});
inputServer.connect();
