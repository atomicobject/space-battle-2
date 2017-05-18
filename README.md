AO RTS
======



### Goal

Write an AI to command your troops to gather the most resources in the time allotted.

### API

The server will connect to your client. You will start receiving messages in the format:

    {
      player: 0,
      turn: 12,
      time: 300000, // time remaining in game
      'unit-updates': [{ // your unit's updates
        id:16,
        player_id: 0,
        x: 0, y: 0,
        status:"moving",
        type:"worker",
        resource:0,
        health:5,
        can_attack:true // cooldown is ready
      }],
      'tile-updates': [{
        // relative to your base
        x: 7, y: -9,
        visible: true,
        blocked: null,
        resources: null,
        units: [{
          id:60,
          x: 7, y: -9
          type:"tank",
          status:"unknown", // tile update statuses can only be unknown or dead
          player_id: 1,
          health: 10
        }]}
      ],
    }
    
To command your units:


    {
      commands: [
        {command: "MOVE", unit: 2, dir: "N"},
        {command: "MOVE", unit: 3, dir: "S"},
        {command: "GATHER", unit: 7, dir: "S"},
        {command: "CREATE", type: "worker"},
        {command: "ATTACK", unit: 4, dx: 3, dy: 2},
      ]
    }

#### Warning!

    The protocol is newline delimited. Make sure your JSON has its newlines stripped!


##### unit-updates
Any time something about a unit changes, (position, status, etc), you will receive an update.

##### tile-updates
Any time something about a tile changes, (occupants, visibility, etc), you will receive an update.

##### time
This is the amount of time remaining in the game (in milliseconds). 


### Commands

__MOVE__: `unit`,`dir` Move a unit by id in a given direction `N,S,E,W`. Command will be ignored if the unit cannot move in the specified direction.

__GATHER__: `unit`,`dir` Tell a unit to collect from a resource in the specified direction `N,S,E,W`. Command will be ignored if the unit cannot gather in the specified direction. Resources are automatically deposited by walking over the players base.

__CREATE__: `type` Create a new unit by type: `worker,scout,tank`. Command is ignored if the player's base does not have enough resources.

__ATTACK__: `unit`,`dx`,`dy` Tell the unit to attack a location relative to the attacker. All units at the location will be damaged (including your own). Command is ignored if the location is out of the attacker's range.


### Running the game

	$ruby src/app.rb --help
	usage: src/app.rb [options]
    -p1,  --p1_host  player 1 host, default localhost
    -p1p, --p1_port  player 1 port, default 9090
    -p2,  --p2_host  player 2 host
    -p2p, --p2_port  player 2 port
    -m,   --map      map filename to play (tmx format)
    -q,   --quiet    suppress output (quiet mode)
    -l,   --log      log entire game
    -f,   --fast     advance to the next turn as soon as all clients have sent a message
    -nu,  --no_ui    No GUI; exit code is winning player
    -t,   --time     length of game in ms
    --help           print this help

**Notes**

1. Disconnecting. Game will continue, but you will lose control of your units.
2. Games are logged to game-log.txt.
