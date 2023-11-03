# Space Battle 2 Player SDK, Ruby

## Basic commands
Run a player with either `rake run` or `ruby rts.rb [port number]`

## Setup
1. Set up a recent version of ruby if you don’t already have one
2. Run `gem install bundler` if you don’t already have it installed
3. Run `bundle install`

## Running with Docker

The included Dockerfile will copy, install deps, and run with `ruby`

To build:

```sh
docker buildx build -f Dockerfile ./ -t client-ruby
```

To run:

```sh
docker run -p 9090:9090 client-ruby
```

