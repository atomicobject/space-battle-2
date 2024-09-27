# Space Battle 2 Game Server

A game server, written in Ruby that hosts an RTS game for up to 2 players. Players connect to the server over websockets.

## Setup

To run the game server, you’ll need a recent version of Ruby and also the SDL2 library. You can install SDL2 with `brew install sdl2`. You’ll need to do that before running `bundle install` or the `gosu` gem installation will fail.

- install ruby 2.3.x or newer
- install [Gosu](https://www.libgosu.org/ruby.html) dependencies ([mac](https://github.com/gosu/gosu/wiki/Getting-Started-on-OS-X) | [linux](https://github.com/gosu/gosu/wiki/Getting-Started-on-Linux))
- install bundler: `gem install bundler`
- `bundle install`
- `ruby src/app.rb`

## Running the Server

`ruby src/app.rb` starts a server. The server expects any clients to already be online when it’s initialized.

Run `ruby src/app.rb --help` for help

```sh
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
```
