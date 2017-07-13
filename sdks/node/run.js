const NodeClient = require('./node-client');

let ip = process.argv.length > 2 ? process.argv[2] : '127.0.0.1';
let port = process.argv.length > 3 ? process.argv[3] : '8080';

let map;
let mapUnits = [];

let client = new NodeClient(ip, port, dataUpdates => {
  updateMap(dataUpdates, map);
  mapUnits = updateUnits(dataUpdates, mapUnits);
}, () => {
  let cmds = generateCommands(mapUnits, map);
  console.log(cmds);
  return cmds;
});

function updateMap(dataUpdates, map) {
  // Update your map based on data updates, if you're into
  // that kind of thing
}

function updateUnits(dataUpdates, units) {
  // Update your units based on data updates
  // Currently this code just maintains an array of your unit's ids
  let ids = units.concat(dataUpdates.unit_updates.map(u => u.id));
  return ids.filter((val, idx) => ids.indexOf(val) === idx);
}

function generateCommands(units, map) {
  // Generate commands here, currently just choosing a random
  // unit and a random direction
  return [{
    command: 'MOVE',
    dir: ['N','E','S','W'][Math.floor(Math.random() * 4)],
    unit: units[Math.floor(Math.random() * units.length)]
  }];
}
