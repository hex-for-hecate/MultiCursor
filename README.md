# MultiCursor
A node server that sends input events with device identifiers to web apps. For supporting multiple cursors in web apps.

## Usage
Start the server with "node multicursorserver".

Start the client by opening test.html.

Note: There are situations where the server will throw an error because a device appears to be plugged in but is not communicative, or will not add a mouse because it has become inactive. Disconnecting and reconnecting usually does the trick.

## Structure

## Components
Inspired by CPN2000, the structure in the web code would probably be universal event processor checks id and then dispatches the event to the appropriate sate machine based on that. This implies that we can actually make it a pointerevent or a mouseevent. So we might not change the type, but we need some trivial way to suppress ‘legacy’ mouse events to avoid the potential pain.
