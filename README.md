# MultiCursor
A node server that sends input events with device identifiers to web apps. For supporting multiple cursors in web apps.

This is a not-very-stable work in progress. 
The library the project relies on (node-hid) is not very well-documented, and I am currently unsure whether it supports listening to input devices without 'taking them over'.

## Usage
Start the server with "node src/server.js".

Start the client by opening src/test.html

Note: There are situations where the server will throw an error because a device appears to be plugged in but is not communicative, or will not add a mouse because it has become inactive. Disconnecting and reconnecting usually does the trick.
