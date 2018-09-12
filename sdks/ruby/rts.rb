require 'socket'
require 'json'
require 'set'
require 'pry'
require 'forwardable'
require_relative "command_builder"
require_relative "random_strategy"


# GOALS FOR SDKS
# - track game state for them
# - project based (Gemfile/rspec)
# - sample unit test
# - A* library picked out (added to Gemfile/package.json/etc)
# - Explicit types
# - CommandBuilder: functions to build each command
# - random movement, pick up resources that are next to it
# - nice README: 
#      what's included
#      how to run
#      how to run tests
#      where to change code


module JSONStruct
  module ClassMethods
    def from_json(json)
      new.tap do |obj|
        obj.update_from_json(json)
      end
    end
  end

  def self.included(child)
    child.extend ClassMethods
  end

  def update_from_json(json)
    json.each do |k,v|
      self.send("#{k}=", v)
    end
  end
end

class Unit
  include JSONStruct
  attr_accessor :id, :player_id, :x, :y, :type, :status, :health, :range, :speed, :resource,
                :can_attack, :attack_damage, :attack_cooldown_duration, :attack_cooldown, :attack_type
  STATUSES = %w[idle moving building dead unknown].freeze
  def idle?
    @status == 'idle'
  end

  def moving?
    @status == 'moving'
  end

  def dead?
    @status == 'dead'
  end
end

class EnemyUnit
  include JSONStruct
  attr_accessor :id, :player_id, :type, :status, :health
end

class Tile
  include JSONStruct
  attr_accessor :visible, :x, :y, :blocked, :resources, :units
end

class TileResource
  include JSONStruct
  attr_accessor :id, :type, :total, :value
end

class GameInfo
  include JSONStruct
  attr_accessor :map_width, :map_height, :game_duration, :turn_duration, :unit_info
end

class ClientTile
  extend Forwardable

  attr_reader :x, :y
  attr_accessor :tile

  def initialize(x, y)
    @x = x
    @y = y
  end

  def resource
    @tile&.resources
  end

  def blocked?
    @tile ? @tile.blocked : true
  end

  def visible?
    @tile ? @tile.visible : false
  end

  def enemy_units
    @tile&.units || []
  end
end

class World
  attr_reader :game_info
  def units
    @units_by_id.values
  end

  def get(x, y)
    trans_x = x + @game_info.map_width
    trans_y = y + @game_info.map_height
    row = @map[trans_x]
    row && row[trans_y]
  end

  # private stuff below

  def reset!(game_info)
    @game_info = GameInfo.from_json game_info
    @units_by_id = {}
    # build an array that is accessible by @map[x][y]
    @map = Array.new(2 * @game_info.map_height) do |x|
      Array.new(2 * @game_info.map_width) do |y|
        ClientTile.new(x-@game_info.map_width, y-@game_info.map_height)
      end
    end
  end

  # Update information about our own units
  def apply_unit_updates!(unit_updates)
    unit_updates.each do |uu|
      known_unit = @units_by_id[uu['id']]
      if known_unit
        known_unit.update_from_json uu
      else
        u = Unit.from_json uu
        @units_by_id[u.id] = u
      end
    end
  end

  def apply_tile_updates!(tile_updates)
    tile_updates.each do |tu|
      get(tu['x'], tu['y']).tile = Tile.from_json tu
    end
  end
end

class Game
  def initialize(outside_world, strategy)
    @world = outside_world
    @strategy = strategy
  end

  def process_updates_from_server(msgs)
    msgs.each do |msg|
      @world.reset! msg['game_info'] if msg['game_info']
      @world.apply_tile_updates! msg['tile_updates'] if msg['tile_updates']
      @world.apply_unit_updates! msg['unit_updates'] if msg['unit_updates']
    end

    # return commands for your units
    { commands: @strategy.commands }
  end
end

if $0 == __FILE__
  port = ARGV[0] || 9090
  server = TCPServer.new port
  Thread.abort_on_exception = true
  loop do
    puts "waiting for connection on #{port}"
    Thread.new(server.accept) do |server_connection|
      world = World.new
      strat = RandomStrategy.new(world)
      game = Game.new(world, strat) 
      msg_from_server = Queue.new

      # listening_thread =
      Thread.new do
        begin
          while msg = server_connection.gets
            msg_from_server.push JSON.parse(msg)
          end
        end
      end

      loop do
        msg = msg_from_server.pop
        msgs = [msg]
        until msg_from_server.empty?
          puts "!!! missed turn!"
          msgs << msg_from_server.pop 
        end

        commands = game.process_updates_from_server(msgs)
        server_connection.puts(commands.to_json)
      end

      server_connection.close
    end
  end
end
