AO RTS - Clojure Starter Kit
============================

This project provides an easy environment for getting started developing your
very own AI for the 2017 Atomic Games.

## Requirements

First, you'll need to get the game server running and familiarize yourself with
the JSON format it uses to communicate with the player AIs.

Next, you'll need to have Leiningen 2.0 or greater installed. I recommend using
Homebrew on MacOS to install Leiningen.

## Getting started

This starter kit does all the work of setting up a TCP server and parsing JSON
from the game server. One important note: the JSON parsing code also converts
the keys to and from "snake_case" Strings and "kebab-case" keywords.

E.g., "player_id" in the JSON becomes :player-id in Clojure, and vice versa.

To define your AI, you'll start by editing src/rts/ai.clj.

## Development workflow

By using `lein repl` to launch the Clojure REPL, you'll automatically be dumped
into the rts.repl namespace. To start the AI within the REPL, you can use the
`go` fn. The REPL server will listen on port 42420.

    rts.repl=> (go)
    
After you already have the server running, you can use the `restart` fn to
automatically:

- Tear down the server
- Reload all your code
- Restart the server

Like so:

    rts.repl=> (restart)
    
This should be fairly reliable, but if you totally wreck your code, you may
need to restart your repl.

## Running normally

If you don't desire the ability to easily reload your code and restart the
server, you can also use leiningen to run the rts.core namespace. This will
start the server listening on port 9090, which is the default for the game
server.

    lein run
    
## Other notes

Clojure 1.9 alpha and Clojure Spec alpha are included.

The namespace `rts.server.messages` includes some sketches for Spec-ing the
messages sent to and received from the server, but they happen to already be
out of date.
