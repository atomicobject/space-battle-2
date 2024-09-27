# Protocal Specification

## JSON Schema

### Message from Server

| property     | type                                    | notes                                             |
| ------------ | --------------------------------------- | ------------------------------------------------- |
| time         | int                                     | Milliseconds left in the game                     |
| turn         | int                                     | Current turn of the game                          |
| player_id    | int                                     | Your player id                                    |
| tile_updates | array of [Tile](#tile)                  | Tiles that changed last turn                      |
| unit_updates | array of [Unit](#unit)                  | Your units that changed last turn                 |
| game_info    | [Game Info](#game-info)                 | Game settings, only sent on turn 0                |
| results      | map of player id to [Results](#results) | Results of game, only sent once game has finished |

#### Unit

| property     | type   | notes                                       |
| ------------ | ------ | ------------------------------------------- |
| id           | int    | Unique identifier for the unit.             |
| player_id    | int    | Your player identifier.                     |
| x            | int    | Tile coord (positive to the right "E")      |
| y            | int    | Tile coord (positive is down "S")           |
| type         | string | Type of unit (base, worker, scout, tank)    |
| status       | string | current status (idle,moving,building,dead)  |
| health       | int    | Current health of unit                      |
| resource\*   | int    | Value of resources currently being carried. |
| can_attack\* | bool   | Can attack next turn (based on cooldown)    |

**\* Optional:** may or may not be present depending on the unit type.

#### Tile

| property  | type                                    | notes                                              |
| --------- | --------------------------------------- | -------------------------------------------------- |
| visible   | bool                                    | Can currently be seen by one of your units         |
| x         | int                                     | Tile coord (positive to the right "E")             |
| y         | int                                     | Tile coord (positive is down "S")                  |
| blocked   | bool                                    | Tile can be walked on by units.                    |
| resources | null or [Tile Resource](#tile-resource) | Description of the resource (if any) on this tile. |
| units     | array of [Enemy Unit](#enemy-unit)      | Enemies found on this tile.                        |

#### Tile Resource

| property | type   | notes                                        |
| -------- | ------ | -------------------------------------------- |
| id       | int    | Unique identifier for this resource.         |
| type     | string | Time of resource (small or large)            |
| total    | int    | Total amount of value left in this resource. |
| value    | int    | Value of a single harvested load.            |

#### Enemy Unit

| property  | type   | notes                                       |
| --------- | ------ | ------------------------------------------- |
| id        | int    | Unique identifier for the unit.             |
| type      | string | Type of unit (base, worker, scout, tank)    |
| status    | string | limited current status (dead or unknown)    |
| player_id | int    | Identifier of the player that owns the unit |
| health    | int    | Current health of unit                      |

#### Game Info

| property      | type                                                 | notes                               |
| ------------- | ---------------------------------------------------- | ----------------------------------- |
| map_width     | int                                                  | Map width in tiles                  |
| map_height    | int                                                  | Map height in tiles                 |
| game_duration | int                                                  | Length of game in milliseconds      |
| turn_duration | int                                                  | Length of each turn in milliseconds |
| unit_info     | map of Unit type (string) to [Unit Info](#unit-info) | Information about each unit type    |

#### Unit Info

| property                 | type   | notes                                                           |
| ------------------------ | ------ | --------------------------------------------------------------- |
| hp                       | int    | Initial health of units                                         |
| range                    | int    | Number of tiles in any direction the unit can see               |
| cost                     | int    | Resource cost to create (optional)                              |
| create_time              | int    | the number of turns it takes to create (optional)               |
| speed                    | float  | Movement speed of unit in turns per tile of movement (optional) |
| attack_type              | string | melee or ranged (optional)                                      |
| attack_damage            | int    | Damage dealt by this unit (optional)                            |
| attack_cooldown_duration | int    | number of turns the unit must wait between attacks (optional)   |
| attack_cooldown          | int    | number of turns the unit must wait to attack again (optional)   |
| can_carry                | bool   | true if the unit can HARVEST and carry resources (optional)     |

#### Results

| property | type | notes                    |
| -------- | ---- | ------------------------ |
| score    | int  | Total score for the game |

### Commands to Server

| property | type                         | notes                                      |
| -------- | ---------------------------- | ------------------------------------------ |
| commands | array of [Command](#command) | Commands for your troops for a single turn |

> [!Note]
> The protocol is newline delimited. Make sure your JSON has all but its last newline stripped. The starter kit SDKs should handle this for you.

#### Command

One of [Move](#move), [Gather](#gather), [Drop](#drop), [Create](#create), [Shoot](#shoot), [Melee](#melee), [Identify](#identify)

##### Move

| property | type               | notes                                              |
| -------- | ------------------ | -------------------------------------------------- |
| command  | "MOVE"             |                                                    |
| unit     | int                | id of the unit to move                             |
| dir      | "N", "E", "S", "W" | direction to move (E - positive x, S - positive y) |

##### Gather

| property | type               | notes                                                     |
| -------- | ------------------ | --------------------------------------------------------- |
| command  | "GATHER"           |                                                           |
| unit     | int                | id of the unit that will gather                           |
| dir      | "N", "E", "S", "W" | direction to gather from (E - positive x, S - positive y) |

##### Drop

| property | type               | notes                                                     |
| -------- | ------------------ | --------------------------------------------------------- |
| command  | "DROP"             |                                                           |
| unit     | int                | id of the unit that will drop                             |
| dir      | "N", "E", "S", "W" | direction to drop toward (E - positive x, S - positive y) |
| value    | int                | amount of resources to drop                               |

##### Create

| property | type                         | notes                        |
| -------- | ---------------------------- | ---------------------------- |
| command  | "CREATE"                     |                              |
| type     | "worker", "scout", or "tank" | the type of unit to purchase |

##### Shoot

| property | type    | notes                                                                |
| -------- | ------- | -------------------------------------------------------------------- |
| command  | "SHOOT" |                                                                      |
| unit     | int     | the id of the shooting unit                                          |
| dx       | int     | number of tiles in the x direction to target relative to the shooter |
| dy       | int     | number of tiles in the y direction to target relative to the shooter |

##### Melee

| property | type    | notes                            |
| -------- | ------- | -------------------------------- |
| command  | "MELEE" |                                  |
| unit     | int     | the id of attacking unit         |
| target   | int     | the id of the target unit/player |

##### Identify

| property | type       | notes                                                    |
| -------- | ---------- | -------------------------------------------------------- |
| command  | "IDENTIFY" |                                                          |
| unit\*   | int        | id of the unit to identify (or the player if left blank) |
| name     | string     | name to assign to the specified unit                     |
