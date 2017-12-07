# MultiCursor
This is a node server that captures USB HID devices and sends their input to your client.
It was created to support tracking mouse events by device in the browser, to enable e.g. two-mouse bimanual interaction.

The library the project relies on, `node-hid`, is not very well-documented, and I am currently unsure whether it supports listening to input devices without 'taking them over'.

## Requirements
node  
npm  
typescript  

## Usage
To adapt this project for your needs, you need to customize `server/main.ts` with Recognizers and Transformers to recognize your USB devices and transform their HID input data to something useful to your client app.
`server/main.ts` and `exampleClients/DOMEventClient.js` contain examples that recognize USB mice and send their input data as simple objects describing a mouse's current state.

Recognizers are Objects that contain two functions: `recognize`, a predicate that takes a `node-hid` device descriptor and returns true if it is the appropriate kind of device, and `register`, a function that produces some appropriate metadata from the same device descriptor.
`register` must return an object that has an `id` value, to track the device by.

Transformers are Objects that contain two functions: `recognize`, a predicate that takes the metadata produced by a Recognizer and returns true if the transformer should be applied to the device, and `transform`, a function that transforms the `node-hid` device input data into a format that will be sent to your client app.

`npm install` to install dependencies.  
`tsc server/main.ts` to transpile the input server to javascript.  
Start the server with `node server/main.js`.

Start the test client by opening `exampleClients/test.html`. NB: Outdated right now.

Note: There are situations where the server will throw an error because a device appears to be plugged in but is not communicative, or will not add a mouse because it has become inactive. Restarting usually does the trick.
