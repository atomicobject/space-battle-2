AO RTS
======

![boxart](SB2RC_CoverArtSmall.png "boxart")


## Goal

Write an AI to command your troops to gather the most resources in the time allotted. You gather resources by exploring the map, finding resources, executing a gather action, and then returning to your base with the gathered resources. The AI communicates over TCP via a JSON protocol.


![gameplay](SB2RC_GameplaySmall.png "gameplay")

## API

The server will connect to your client. You will start receiving messages in the format:

```
{
  player: 0,
  turn: 12,
  time: 300000, // time remaining in game
  'unit_updates': [{ // your unit's updates
    id:16,
    player_id: 0,
    x: 0, y: 0,
    status:"moving",
    type:"worker",
    resource:0,
    health:5,
    can_attack:true // cooldown is ready
  }],
  'tile_updates': [{
    // relative to your base
    x: 7, y: -9,
    visible: true,
    blocked: false,
    resources: {
      id: 12,
      type: "small",
      total:200,
  value:10
    },
    units: [{
      id:60,
      type:"tank",
      status:"unknown", // tile update statuses can only be unknown or dead
      player_id: 1,
      health: 10
    }]}
  ],
}
```

##### unit_updates
Any time something about one of your units changes, (position, status, etc), you will receive an update.

##### tile_updates
Any time something about a tile changes, (enemy units, visibility, etc), you will receive an update.

##### time
This is the amount of time remaining in the game (in milliseconds).

##### turn
This is the current turn of the game. Each turn is 200ms.

### Sending commands
To command your units, send messages to the server using the format:

```
{
  commands: [
    {command: "MOVE", unit: 2, dir: "N"},
    {command: "MOVE", unit: 3, dir: "S"},
    {command: "GATHER", unit: 7, dir: "S"},
    {command: "CREATE", type: "worker"},
    {command: "SHOOT", unit: 4, dx: 3, dy: 2},
    {command: "MELEE", unit: 4, target: 2},
  ]
}
```

#### Warning!

    The protocol is newline delimited. Make sure your JSON has all but its last newline stripped!



***

## Commands

Commands are your AI's way of telling the server what you want your units to do. Some commands take many turns to complete. When finished executing a command, a unit's status will be set to `idle`.

__MOVE__: `unit`,`dir` Move a unit by id in a given direction `N,S,E,W`. Command will be ignored if the unit cannot move in the specified direction or is currently executing a previous `MOVE` command. Units _**can**_ occupy the same location.

__GATHER__: `unit`,`dir` Tell a unit to collect from a resource in the specified direction `N,S,E,W`. Command will be ignored if the unit cannot gather in the specified direction. Resources are automatically deposited by walking over the players base.

__CREATE__: `type` Create a new unit by type: `worker,scout,tank`. Command is ignored if the player's base does not have enough resources.

__SHOOT__: `unit`,`dx`,`dy` Tell the unit to shoot a location relative to the attacker. All units at the location will be damaged (including your own). Command is ignored if the location is out of the attacker's range (within unit vision). Each unit has an attack cooldown. `can_attack` will be sent down as `true` when they can attack again.

__MELEE__: `unit`,`target` Tell the unit to melee a nearby unit. Command is ignored if target unit is more than a single tile away. Each unit has an attack cooldown. `can_attack` will be sent down as `true` when they can attack again.

__IDENTIFY__: `unit`, `name` Name the unit (or player if left blank). This name will only show on the graphical server window. Command is ignored if the unit is owned by another player.

#### Note:
    When a unit has died, its status will be set to "dead".
    Dead units will no longer respond to your commands.
***


## Units
![base](server/assets/PNG/Retina/Other/base_red.png "base")

__BASE__: When joining the game, your base will be placed at a random location on the map. Map locations will be sent from the server relative to your base's location (i.e. A location of x: 1, y: 1 would indicate the tile 1 step east and 1 step south of your base).

![worker](server/assets/PNG/Retina/Other/worker_red.png "worker")

__WORKER__: You will start the game with 6 workers. Workers are the only unit that can carry resources. They have average vision, speed, health, and a weak melee attack. Cost: 100.

![scout](server/assets/PNG/Retina/Other/scout_red.png "scout")

__SCOUT__: Scouts have longer vision, faster speed, lower health, and a weak melee attack. Cost 130.

![tank](server/assets/PNG/Retina/Other/tank_red.png "tank")

__TANK__: Tanks have average vision, slower speed, higher health, and a ranged attack. Cost 150.

| type   | cost | range (+/-) | speed (tpt<sup>*</sup>) | health | attack cooldown (turns) | attack damage | build time (turns) |
|--------|------|-------|-------|--------|-----------------|---|---|
| worker | 100  | 2     | 5     | 10     | 3 | 2 | 5  |
| scout  | 130  | 5     | 3     | 5      | 3 | 1 | 10 |
| tank   | 150  | 2     | 10    | 20     | 7 | 4 | 15 |

<sup>*</sup>__turns per tile (tpt):__ Number of turns required to move from one grid location to the next. Smaller is faster.

***

## Communication Overview

Your chosen starter kit should implement the basic communication protocol with the server.

The server will send updates to each connected AI at the beginning of a turn. The server then waits a specifed amount of time (defaults to 200ms) for each AI to send commands. It processes any received commands and then advances to the next turn.

**Note that in fast mode (which will be used in the tournament) the server will advance to the next turn after it receives a single message from each AI (or the time limit expires) and so you'll want to batch your commands for each turn into a single message.**

Ask your coach if you need detail in addition to what's listed here.


## JSON Schema

### Message from Server

| property | type | notes |
|----------|------|-------|
| `time` | `int` | Milliseconds left in the game |
| `turn` | `int` | Current turn of the game |
| `player_id` | `int` | Your player id |
| `tile_updates` | `array of Tiles` | Tiles that changed last turn |
| `unit_updates` | `array of Units` | Your units that changed last turn |
| `game_info` | `Game Info` | Game settings, only sent on turn 0 |
| `results` | `map of player id to Results` | Results of game, only sent once game has finished |

#### Unit
| property | type | notes |
|----------|------|-------|
| `id` | `int` | Unique identifier for the unit. |
| `player_id` | `int` | Your player identifier. |
| `x` | `int` | Tile coord (positive to the right "E") |
| `y` | `int` | Tile coord (positive is down "S") |
| `type` | `string` | Type of unit (base, worker, scout, tank) |
| `status` | `string` | current status (idle,moving,building,dead) |
| `health` | `int` | Current health of unit |
| `resource`__*__ | `int` | Value of resources currently being carried. |
| `can_attack`__*__ | `bool` | Can attack next turn (based on cooldown) |

__* Optional:__ may or may not be present depending on the unit type.

#### Tile
| property | type | notes |
|----------|------|-------|
| `visible` | `bool` | Can currently be seen by one of your units |
| `x` | `int` | Tile coord (positive to the right "E") |
| `y` | `int` | Tile coord (positive is down "S") |
| `blocked` | `bool` | Tile can be walked on by units. |
| `resources` | `null` or `Tile Resource` | Description of the resource (if any) on this tile. |
| `units` | `array of Enemy Units` | Enemies found on this tile. |

#### Tile Resource
| property | type | notes |
|----------|------|-------|
| `id` | `int` | Unique identifier for this resource. |
| `type` | `string` | Time of resource (small or large) |
| `total` | `int` | Total amount of value left in this resource. |
| `value` | `int` | Value of a single harvested load. |

#### Enemy Units

| property | type | notes |
|----------|------|-------|
| `id` | `int` | Unique identifier for the unit. |
| `type` | `string` | Type of unit (base, worker, scout, tank) |
| `status` | `string` | limited current status (dead or unknown) |
| `player_id` | `int` | Identifier of the player that owns the unit |
| `health` | `int` | Current health of unit |


#### Game Info
| property | type | notes |
|----------|------|-------|
| `map_width` | `int` | Map width in tiles |
| `map_height` | `int` | Map height in tiles |
| `game_duration` | `int` | Length of game in milliseconds |
| `turn_duration` | `int` | Length of each turn in milliseconds |
| `unit_info` | `map of Unit type to Unit Info` | Information about each unit type |

#### Unit Info
| property | type | notes |
|----------|------|-------|
| `hp` | `int` | Initial health of units |
| `range` | `int` | Number of tiles in any direction the unit can see |
| `cost` | `int` | Resource cost to create (optional) |
| `create_time` | `int` | the number of turns it takes to create (optional) |
| `speed` | `float` | Movement speed of unit in turns per tile of movement (optional) |
| `attack_type` | `string` | melee or ranged (optional) |
| `attack_damage` | `int` | Damage dealt by this unit (optional) |
| `attack_cooldown_duration` | `int` | number of turns the unit must wait between attacks (optional) |
| `attack_cooldown` | `int` | number of turns the unit must wait to attack again (optional) |
| `can_carry` | `bool` | true if the unit can `HARVEST` and carry resources (optional) |


#### Results
| property | type | notes |
|----------|------|-------|
| `score` | `int` | Total score for the game |


## Setting Up the game

* checkout repo
* install ruby 2.3.x or newer
* install [Gosu](https://www.libgosu.org/ruby.html) dependencies ([mac](https://github.com/gosu/gosu/wiki/Getting-Started-on-OS-X) | [linux](https://github.com/gosu/gosu/wiki/Getting-Started-on-Linux))
* install bundler: `gem install bundler`
* `cd server`
* `bundle install`
* `ruby src/app.rb`

## Running the game
    $ruby src/app.rb --help
    usage: src/app.rb [options]
      -p1, --p1_host     player 1 host [localhost]
      -p1p, --p1_port    player 1 port [9090]
      -p2, --p2_host     player 2 host
      -p2p, --p2_port    player 2 port [9090]
      -m, --map          map filename to play (json format) [map.json]
      -l, --log          log entire game to game-log.txt
      -f, --fast         advance to the next turn as soon as all clients have sent a message
      -fs, --fullscreen  Run in fullscreen mode
      -nu, --no_ui       No GUI; exit code is winning player
      -t, --time         length of game in ms [300000]
      -drb, --drb_port   debugging port for tests
      -p1n, --p1_name    player 1 name
      -p2n, --p2_name    player 2 name
      --help             print this help

**Notes**

1. Disconnecting. Game will continue, but you will lose control of your units.
2. Games are logged to `game-log.txt`


## Creating your own maps

You may want to test out edge cases or set up situations for testing that are not in the training maps. Maps are built using [Tiled](http://www.mapeditor.org/). To build your own:

* Download and Install Tiled
* Copy an existing map
* Update layers
   * blocked layer has cells filled in that are not walkable
   * objects has resources and base starting locations _(copying existing resources/bases will maintain needed type properties)_
   * environment has decorative tiles
* export the map as JSON with Map -> Properties -> Tile Layer Format set to CSV
