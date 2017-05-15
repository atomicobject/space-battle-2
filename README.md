AO RTS
======



### Goal

Write an AI to command your troops to gather the most resources in the time allotted.

### API

The server will connect to your client. You will start receiving messages in the format:


    {
      player: 0,
      turn: 12,
      time: 300000,
      'unit-updates': [
        {id: 'XYZ', health: 2}
      ],
      'tile-updates': [
        // relative to your base
        {x: 5, y: -2, blocked: true},
      ],
    }
    
To command your units:


    {
      commands: [
        {command: "MOVE", unit: "XYZ", dir: "N"},
        {command: "MOVE", unit: "ABC", dir: "S"},
        {command: "GATHER", unit: "123", dir: "S"},
        {command: "CREATE", type: "worker"},
      ]
    }


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


**Notes**

1. Disconnecting. Game will continue, but you will lose control of your units.
