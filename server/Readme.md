# Space Battle 2 Game Server

A game server, written in Ruby that hosts an RTS game for up to 2 players. Players connect to the server over websockets.

## Setup

To run the game server, you’ll need a recent version of Ruby and also the SDL2 library. You can install SDL2 with `brew install sdl2`. You’ll need to do that before running `bundle install` or the `gosu` gem installation will fail.
