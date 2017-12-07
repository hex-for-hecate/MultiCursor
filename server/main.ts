import {InputServer, DeviceDescriptor, DeviceData} from './InputServer';

const WEBSOCKET_PORT = 7777;

let mouseRecognizer = {
    recognize: function(desc: DeviceDescriptor) {
        return desc.usagePage === 1 && desc.usage === 2;
    },
    register: function(desc: DeviceDescriptor) {
        return {
            type: 'mouse',
            id: desc.path,
            developerMouseChosen: false
        }
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

const buttonMap = {
    0: [false, false, false],
    1: [true, false, false],
    2: [false, false, true],
    3: [true, false, true],
    4: [false, true, false],
    5: [true, true, false],
    6: [true, true, true]
}

let mouseDataTransformer = {
    recognize: function(metadata) {
        return metadata.type === 'mouse';
    },
    transform: function(data: DeviceData, metadata: any) {
        if (!metadata.developerMouseChosen && data[0] > 0) {
            console.log(`${metadata.id} is the developer mouse.`);

            // close the developer mouse and stop tracking it
            this.devices[metadata.id].device.close();
            delete this.devices[metadata.id];

            // update all mice to indicate that the developer mouse has been chosen
            for (let id in this.devices) {
                let metadata = this.devices[id].metadata;
                if (metadata.type === 'mouse') {
                    metadata.developerMouseChosen = true;
                }
            }

            // do not send this result
            return false;
        }

        let result = {};

        let buttons = buttonMap[data[0]];
        result['left'] = buttons[0];
        result['middle'] = buttons[1];
        result['right'] = buttons[2];

        let movedelta = [data[1], data[2]].map(n => n > 128 ? n - 256 : n);
        result['dx'] = movedelta[0];
        result['dy'] = movedelta[1];

        result['scroll'] = data[3];

        result['id'] = metadata.id;

        return result;
    }
};

// TODO a specialized recognizer for the apple trackpad and transformer
// TODO proof-of-concept code for generating DOM Events to show general usability of the InputServer

let inputServer = new InputServer({
    clientURL: WEBSOCKET_PORT,
    recognizers: [mouseRecognizer],
    transformers: [mouseDataTransformer]
});

inputServer.connect();
