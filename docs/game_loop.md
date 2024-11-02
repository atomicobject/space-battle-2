# The game loop

Your job in this challenge is to develop an AI game client that can play the game by communicating with a game server. This guide serves to describe the communication patterns between client and server that constitute the core game loop. More technical details about the communication protocol can be found in the [protocol spec](./protocol_spec.md).

## Connection

Once your client is running, it will wait until it successfully connects to the server via TCP. The game will not start until the server connects to all player clients.

The starter kit SDKs are all implemented to handle connection logic for you.

## Server Message

At the start of each turn, the server will send your client a message that defines the updates that happened on the previous turn. This message will be in the format defined in [the spec](./protocol_spec.md#message-from-server).

On the very first turn, the server's message will include additional info about the configuration of the game. This includes details like the size of the map, duration of the game, and time allowed per turn. The shape of this info is defined in [game info](./protocol_spec.md#game-info).

When the game finishes, a final message will be sent from the server that includes the results of the game. The format of results can also be found in [the spec](./protocol_spec.md#results).

> [!Note]
> The updates sent by the server do _not_ include the entire state of the game. It only provides information about things that your units can observe and have changed since the last turn.
> Did you leave a unit parked next to a resource? The server will only tell you that once, until something about that resource changes.

## Your Turn

Now the server has told you the latest state of the map. It's your turn to decide what to do next.

This is the part in the starter kit SDKs where the algorithm picks a bunch of random moves to make.

You should reimplement this algorithm to do something smarter.

Some ideas:

- Efficiently explore the map (how else will you find resources or enemies? -- _and_ % of map explored is a tie breaker)
- Tell a unit that's carrying resources what the quickest way back to base is
- Evaluate your current resource balance (can you afford more workers?)
- Engage in a fight (but be prepared to win!)

You only have a short time to make these decisions and the game will move on without you if you miss your turn. Prioritize your decision making options.

## Commands

Know what you want to do? You need to tell the server about it.

Formulate your decisions into the message types [described here](./protocol_spec.md#commands-to-server) and use the provided SDK implementations to send that message to the server.

Remember to batch your commands into a single message so that the turn doesn't end before you submit all your moves.

## Repeat

When the turn duration expires or all players submit commands, the loop repeats. The server will process commands from all players and [respond with the relevant updates](#server-message) for each player.
