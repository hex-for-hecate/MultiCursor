# MultiCursorOSX
An OSX app which sends input events with device identifiers to web apps. For supporting multiple cursors in web apps.

## Requirements for a bimanual interaction skim on OSX:
  write it as an app which registers all (mouse) input events and sends them to the browser through a web socket. The events need two distinguishing features
 - a device id, so several mice can appear as different event sources. The device id can be persistent or session-based.
 -  possibly a new event family, so one can ignore common browser mouse/pointer events.

Ideally, we would want things to degrade gracefully, if the skim isn’t active, i.e. revert to just using browser events. However, since this may involve moving away from bimanual support altogether, can we really automate it?

## Structure
Cocoa app ={JSON describing mouse events with device id}=> 
Web Worker ={js object to fill into an Event}=>  
mouseevent emitter in main browser thread ={mouseevent with device id in detail field}=>
device-specific mouse object in main browser thread

I don’t think the Web Worker can full-on send over the Event object, because it might need the window object. I should investigate this, because it might simplify the code if the worker is literally transmitting an Event object.

It turns out that it’s perfectly useful that I am using devices as event funnels already, so I actually don’t care about the browser’s way of determining what was clicked, which would be impossible to tell from the Cocoa app anyway.


## Components
Inspired by CPN2000, the structure in the web code would probably be universal event processor checks id and then dispatches the event to the appropriate sate machine based on that. This implies that we can actually make it a pointerevent or a mouseevent. So we might not change the type, but we need some trivial way to suppress ‘legacy’ mouse events to avoid the potential pain.

```javascript
// if we are using multicursor events, ignore mouse events with no device identifier
if (!!multicursor && event.type === ‘mouseevent’ && event.sourcedevice === undefined) {
  return;
}
// …then pass the event along, sending it to a default ‘primary’ if it has no sourcedevice?
// I guess in practice we would check if we are using the library before this, when we determine what interaction techniques to make available, so just sending regular events to a primary interaction technique is not going to be a solution.
```

Apparently Cocoa doesn’t have device id’s built into its event model, but there is a library called DDHidLib which allows us to get low-level events from USB devices ( I think ). It may be possible to match HID events to Cocoa events, attaching the id that way. It’s unclear how well that strategy would work when we are moving two mice concurrently, but we ought to check it out.

On the client side, we can probably create a Web Worker which manages the web socket connection with the local event monitor, and emits events that can be picked up by the web app.
Communication with workers is done through message posting, which means I would probably need something like

```javascript
MCEWorker.onmessage = function(e) {
  let msg = e.data;
  let mouseevent = new Event(msg.type, { 
    detail: msg.detail,
    bubbles: true,
    cancelable: true,
    view: window,
    screenX: msg.x,
    screenY: msg.y
  });
  document.dispatchEvent(mouseevent);
}
```

whereas in the worker, there’s something like

```javascript
//should have useful error handling here that allows the connection to be established independent of whether the app or the web page are started first
let server = new WebSocket(“ws://127.0.0.1:1234”);
// receive JSON object through web socket connected to Cocoa app
server.onmessage = function(e) {
  let msg = JSON.parse(e.data);
  let browserevent = {
    eventtype: …,
    eventdetail: …,
    x: …,
    y: …,
    // button press info, possibly modifiers
  }
  postMessage(browserevent);
}
```


It’s possible that the Worker step is overkill, but parallel execution is cool, so there.
