/*jshint esversion: 6 */

/* Capture and represent all mice */
/* I need to distribute responsibility between the event emitter and the mouse abstraction.  I don't think the event emitter should be doing anything aside from packaging the data into events.
 * The mouse abstraction should do the summing.
 */

/* Event emitter, which manages the websocket connection and creates local events on document.
 * This is the code you want to copy-paste into your multi-cusor application.
 * TODO: How do I package this in such a way that there is no need to copy-paste a code block,
 * but rather one, e.g., creates Mouse instances after importing it as a library? 
 * */

/* This is the block you would put in your client side code to interface with the MultiCursor server */
/* To actually pick up fired events, it looks like they have to be CustomEvents.
 * Handlers with manually specified type will still pick them up,
 * but I can only add my own detail field if I do it like that.
 *
 */
class MultiCursorEventEmitter {
    constructor(url, registerDevices, handleMouseEvents) {
        //the port on which the server is communicating.
        this.url = url;
        //callback function, should receive an array of device id's which can later be used to identify events.
        this.registerDevices = registerDevices;
        //callback function, should receive event messages and generate events.
        this.handleMouseEvents = handleMouseEvents;
    }

    init() {
        let ws = new WebSocket(this.url);
        ws.addEventListener("open", function(e) {
            console.log("Socket connection opened");
        });
        ws.addEventListener("message", (msg) => {
            let data = JSON.parse(msg.data);
            if (data.type === "devicelist") {
                this.registerDevices(data.devicelist);
            } else if (data.type === "mousemove" ||
                       data.type === "mousedown" ||
                       data.type === "mouseup") {
                this.handleMouseEvents(data);
            }
        });
    }
}

/* This is an example of how you might consume the data the server sends you, by creating a representation of each mouse on the client side. */
class Mouse {
    constructor(deviceId) {
        this.deviceId = deviceId;
        this.position = [0, 0];
        this.left_click = false;
        this.right_click = false;

        // TODO create an inspectable object representing the mouse's state, whatever that means contextually.
        this.cursor = document.createElement("div");
        this.cursor.classList.add("cursor");
        document.body.appendChild(this.cursor);
        this.cursor.style.left = "0px";
        this.cursor.style.top = "0px";

        // make this mouse track the events of a particular device.
        document.addEventListener("mousemove", (e) => {
            if (e.detail.deviceId === this.deviceId) {
                let delta = e.detail.delta;
                this.position = [this.position[0] + delta[0], this.position[1] + delta[1]];
                this.cursor.style.left = `${this.position[0]}px`;
                this.cursor.style.top = `${this.position[1]}px`;
                console.log(`${this.deviceId} moved!`);
            }
        });
        document.addEventListener("mousedown", (e) => {
            if (e.detail.deviceId === this.deviceId) {
                if (e.detail.buttons % 2 === 1) {
                    this.left_click = true;
                }
                if (e.detail.buttons >= 2) {
                    this.right_click = true;
                }
                this.cursor.classList.add("clicked");
                console.log(`${this.deviceId} was clicked!`);
            }
        });
        document.addEventListener("mouseup", (e) => {
            if (e.detail.deviceId === this.deviceId) {
                if (e.detail.buttons % 2 === 0) {
                    this.left_click = false;
                }
                if (e.detail.buttons < 2) {
                    this.right_click = false;
                }
                this.cursor.classList.remove("clicked");
                console.log(`${this.deviceId} was unclicked!`);
            }
        });

    }
}

const makeMice = (deviceList) => {
    console.log(`registering all mice: ${deviceList}`);
    for (let deviceId of deviceList) {
        let m = new Mouse(deviceId);
    }
};

const generateMouseEvents = (msg) => {
    let data = msg.data;

    /* The read-only detail field is sadly the only way to attach arbitrary data to an event, it seems */
    let detail = { deviceId: msg.deviceId };
    if (msg.type === "mousedown" || msg.type === "mouseup") {
        detail.buttons = data.buttons;
        detail.button = data.button;
    } else if (msg.type === "mousemove") {
        detail.delta = data.delta;
    }

    let event = new CustomEvent(msg.type, { 
        view: window,
        bubbles: true,
        cancelable: true,
        detail: detail
    });

    document.dispatchEvent(event);
};

let MCEE = new MultiCursorEventEmitter("ws:localhost:7777", makeMice, generateMouseEvents);
MCEE.init();

