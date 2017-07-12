let map;
let mapUnits = [];

let client = new NodeClient('127.0.0.1', 8080, dataUpdates => {
  updateMap(dataUpdates, map);
  updateUnits(dataUpdates, mapUnits);
}, () => {
  return generateCommands(mapUnits, map)
});

function updateMap(dataUpdates, map) {
  // Update your map based on data updates
  console.log("Recieved data updates -- ", dataUpdates);
}

function updateUnits(dataUpdates, mapUnits) {
  // Update your units based on data updates
}

function generateCommands(units, map) {
  return [
    // Put commands here
  ];
}
