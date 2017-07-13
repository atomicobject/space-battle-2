# Node RTS SDK

### Getting Started
To run the starter code

```
node run.js
```

This will create an instance of `NodeClient` and listen on `127.0.0.1:8080` for a game to be initiated. Currently, `run.js` will keep track of your unit's ids and randomly choose one unit to move in a random direction. This file is where you'll begin keeping track of the game map tiles and units, and then make decisions and commands based on that.

Currently `node-client.js` handles all of the sending and recieving of JSON through a TCP connection. The IP address and port can be configured via command line arguments, otherwise the default, `127.0.0.1:8080` is used. 

```
node run.js [IP] [PORT]
```

This SDK separates the recieving of data from the sending of commands. If you take too long on a turn, data updates will pile up, but fear not, the processing of these backed up updates will be processed before your commands are asked for. This does allow you the assurance that you always have updated data, but feel free to change this flow as you wish.