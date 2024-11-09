# Tiny Example

> [!Note]  
> This is an example intended to demonstrate mechanics like the game loop, communication protocol, and partial updates.
> Specific interactions in this example should not be considered as source of truth for actual game behavior.

### Tweaks made for brevity

- Tiny map
- No opponent
- All commands complete in 1 turn (i.e. unit status will never be "moving")
- Workers and bases have vision +/- 1
- Unimportant JSON omitted

### Game board legend

- `[ ]`: empty tile
- `b`: base
- `w`: worker
- `r`: resource
- `?`: tile we know nothing about

## Turn 0

Server Message

```json
{
    "player": 1,
    "turn": 0,
    "time": 60000,
    "game_info": {
        "map_width": 3,
        "map_height": 3,
        "game_duration": 60000,
        "turn_duration": 200,
        "unit_info": { ... }
    },
    "unit_updates": [
        {
            "id": 1,
            "player_id": 1,
            "x": 0,
            "y": 0,
            "status": "idle",
            "type": "worker",
            "resource": 0,
            "health": 10,
            "can_attack": true
        },
        {
            "id": 0,
            "player_id": 1,
            "x": 0,
            "y": 0,
            "status": "idle",
            "type": "base",
            "resource": 0,
            "health": 300,
            "can_attack": true
        }
    ],
    "tile_updates": [
        {
            "x": 0,
            "y": 0,
            "visible": true,
            "blocked": false,
            "resources": null,
            "units": []
        },
        {
            "x": 0,
            "y": 1,
            "visible": true,
            "blocked": false,
            "resources": null,
            "units": []
        },
        {
            "x": 1,
            "y": 0,
            "visible": true,
            "blocked": false,
            "resources": null,
            "units": []
        },
        {
            "x": 1,
            "y": 1,
            "visible": true,
            "blocked": false,
            "resources": null,
            "units": []
        }
    ],
}
```

Game State

```
[b][ ][?]
[ ][ ][?]
[?][?][?]
```

Note: base (b) and worker (w) are occupying the same tile

Player's Commands

```json
[{ "command": "MOVE", "unit": 1, "dir": "E" }]
```

## Turn 1

Server Message

```json
{
  "player": 1,
  "turn": 1,
  "time": 59800,
  "unit_updates": [
    {
      "id": 1,
      "player_id": 1,
      "x": 1,
      "y": 0,
      "status": "idle",
      "type": "worker",
      "resource": 0,
      "health": 10,
      "can_attack": true
    }
  ],
  "tile_updates": [
    {
      "x": 2,
      "y": 0,
      "visible": true,
      "blocked": false,
      "resources": null,
      "units": []
    },
    {
      "x": 2,
      "y": 1,
      "visible": true,
      "blocked": false,
      "resources": null,
      "units": []
    }
  ]
}
```

Game State

```
[b][w][ ]
[ ][ ][ ]
[?][?][?]
```

Player's Commands

```json
[{ "command": "MOVE", "unit": 1, "dir": "S" }]
```

## Turn 2

Server Message

```json
{
  "player": 1,
  "turn": 2,
  "time": 59600,
  "unit_updates": [
    {
      "id": 1,
      "player_id": 1,
      "x": 1,
      "y": 1,
      "status": "idle",
      "type": "worker",
      "resource": 0,
      "health": 10,
      "can_attack": true
    }
  ],
  "tile_updates": [
    {
      "x": 0,
      "y": 2,
      "visible": true,
      "blocked": false,
      "resources": null,
      "units": []
    },
    {
      "x": 1,
      "y": 2,
      "visible": true,
      "blocked": false,
      "resources": {
        "id": 0,
        "type": "small",
        "total": 200,
        "value": 10
      },
      "units": []
    },
    {
      "x": 2,
      "y": 2,
      "visible": true,
      "blocked": false,
      "resources": null,
      "units": []
    }
  ]
}
```

Game State

```
[b][ ][ ]
[ ][w][ ]
[ ][r][ ]
```

Player's Commands

```json
[{ "command": "GATHER", "unit": 1, "dir": "S" }]
```
