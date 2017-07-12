const net = require('net');

module.exports = class NodeClient {
  constructor(ip, port, dataCallback, commandsCallback) {
    this.server = net.createServer();
    this.server.listen(port, ip);

    this.updateBacklog = [];

    this.server.on('connection', socket => {
      console.log("Connected to server");

      socket.on('data', data => {
        let stringData = data.toString('utf8').trim();

        stringData.split('\n').forEach(d => this.updateBacklog.push(d));

        // Run all commands in the bank
        while(this.updateBacklog.length > 0) {
          let str = this.updateBacklog.shift();

          if(str.length > 0) {

            try{
              let dataUpdates = JSON.parse( str );
              dataCallback(dataUpdates);
            } catch(e) {
              console.error(e);
            }

          } else {
            // Blank message received from server
          }
        }

        let commands = {
          commands: commandsCallback()
        };

        let messageToSend = JSON.stringify(commands, null, 0) + "\n";
        socket.write(messageToSend);

      });
    });
  }
}
