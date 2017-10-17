require 'slop'
require_relative './rts_window'
require_relative './game'

opts = Slop.parse do |o|
  o.string '-p1', '--p1_host', 'player 1 host [localhost]', default: 'localhost'
  o.integer '-p1p', '--p1_port', 'player 1 port [9090]', default: 9090
  o.string '-p2', '--p2_host', 'player 2 host'
  o.integer '-p2p', '--p2_port', 'player 2 port [9090]', default: 9090
  o.string '-m', '--map', 'map filename to play (json format) [map.json]', default: 'maps/map.json'
  o.bool '-l', '--log', 'log entire game to game-log.txt'
  o.bool '-f', '--fast', 'advance to the next turn as soon as all clients have sent a message'
  o.bool '-fs', '--fullscreen', 'Run in fullscreen mode', default: false
  o.bool '-nu', '--no_ui', 'No GUI; exit code is winning player'
  o.integer '-t', '--time', "length of game in ms [#{RtsGame::GAME_LENGTH_IN_MS}]", default: RtsGame::GAME_LENGTH_IN_MS
  o.integer '-drb', '--drb_port', 'debugging port for tests'
  o.string '-p1n', '--p1_name', 'player 1 name'
  o.string '-p2n', '--p2_name', 'player 2 name'
  o.on '--help', 'print this help' do
    puts o
    exit
  end
end

Thread.abort_on_exception = true
trap("SIGINT") { exit! }

clients = [
  {host: opts[:p1_host], port: opts[:p1_port], name: opts[:p1_name]},
]
clients << {host: opts[:p2_host], port: opts[:p2_port], name: opts[:p2_name]} if opts[:p2_host]

logger = GameLogger::NOOP.new
logger = GameLogger.new if opts[:log]

if opts[:no_ui]
  total_time = 0
  input = InputSnapshot.new nil, total_time

  @game = RtsGame.new map: opts[:map], clients: clients, fast: opts[:fast], time: opts[:time], drb_port: opts[:drb_port], logger: logger
  if opts[:drb_port]
    until @game.game_over?
      sleep 1
    end
  else
    @game.start!
    until @game.game_over?
      @game.update delta: 1000/60, input: []
    end
  end

  @game.scores.each do |id, info|
    puts "Player #{id}: #{info}"
  end
  winner = @game.winner
  puts "Player #{winner} wins!"
  exit winner

  # require 'pry'
  # binding.pry
  # puts "YAY"

else

  $window = RtsWindow.new map: opts[:map], clients: clients, fast: opts[:fast], time: opts[:time],
    drb_port: opts[:drb_port], fullscreen: opts[:fullscreen], logger: logger
  $window.show
end
