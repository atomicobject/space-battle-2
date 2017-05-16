# require 'awesome_print'
require 'json'
require 'thread'
require 'set'

require_relative '../lib/core_ext'
require_relative '../lib/vec'
require_relative '../components/components'
require_relative '../lib/prefab'
require_relative '../systems/render_system'
require_relative '../systems/systems'
require_relative '../lib/world'
require_relative '../lib/map'
require_relative '../lib/entity_manager'
require_relative '../lib/input_cacher'
require_relative '../lib/network_manager'

class GameLogger
  require 'singleton'
  include Singleton
  def initialize
    @log_file = File.open('game-log.txt', 'w+')
  end
  def log(msg)
    @log_file.puts(msg)
  end

  def self.log(msg)
    self.instance.log(msg)
  end
end


class RtsGame
  ASSETS = {
    dirt1: 'assets/PNG/Default Size/Tile/scifiTile_41.png',
    dirt2: 'assets/PNG/Default Size/Tile/scifiTile_42.png',
    tree1: 'assets/PNG/Default Size/Tile/scifiTile_15.png',
    tree2: 'assets/PNG/Default Size/Tile/scifiTile_16.png',
    tree3: 'assets/PNG/Default Size/Tile/scifiTile_27.png',
    tree4: 'assets/PNG/Default Size/Tile/scifiTile_28.png',
    tree5: 'assets/PNG/Default Size/Tile/scifiTile_29.png',
    tree6: 'assets/PNG/Default Size/Tile/scifiTile_30.png',
    base0: 'assets/PNG/Default Size/Structure/scifiStructure_08.png',
    worker0: 'assets/PNG/Default Size/Unit/scifiUnit_02.png',
    scout0: 'assets/PNG/Default Size/Unit/scifiUnit_06.png',
    tank0: 'assets/PNG/Default Size/Unit/scifiUnit_09.png',
    base1: 'assets/PNG/Default Size/Structure/scifiStructure_03.png',
    worker1: 'assets/PNG/Default Size/Unit/scifiUnit_14.png',
    scout1: 'assets/PNG/Default Size/Unit/scifiUnit_18.png',
    tank1: 'assets/PNG/Default Size/Unit/scifiUnit_21.png',
    small_res1: 'assets/PNG/Default Size/Environment/scifiEnvironment_09.png',
    large_res1: 'assets/PNG/Default Size/Environment/scifiEnvironment_10.png',
  }

  MAX_UPDATE_SIZE_IN_MILLIS = 500
  TURN_DURATION = 200
  TILE_SIZE = 64
  SIMULATION_STEP = 20
  STEPS_PER_TURN = TURN_DURATION / SIMULATION_STEP
  STARTING_WORKERS = 5
  GAME_LENGTH_IN_MS = 300_000
  UNITS = {
    base: {
      range: 2,
      hp: 50,
    },
    worker: {
      cost: 100,
      range: 2,
      speed: 1,
      attack: 3,
      hp: 5,
      can_carry: true,
    },
    scout: {
      cost: 130,
      range: 5,
      speed: 2,
      attack: 1,
      hp: 3,
    },
    tank: {
      cost: 150,
      range: 2,
      speed: 0.5,
      attack: 5,
      hp: 10,
    },
  }
  PLAYER_START_RESOURCE = UNITS[:tank][:cost]

  DIR_VECS = {
    'N' => vec(0,-1),
    'S' => vec(0,1),
    'W' => vec(-1,0),
    'E' => vec(1,0),
  }

  attr_accessor :entity_manager, :render_system, :resources

  def initialize(map:,clients:)
    build_world clients, map
    @data_out_queue = Queue.new
    @sync_data_out_thread = Thread.new do
      loop do
        ents, input = @data_out_queue.pop
        input[:messages] && input[:messages].each do |msg|
          GameLogger.log("\nreceived msg from #{msg.connection_id}: #{msg.data}")
        end
        STEPS_PER_TURN.times do
          @world.update @clone, SIMULATION_STEP, input, @resources
          input.delete(:messages)
        end
        @network_manager.clients.each do |player_id|
          msg = generate_message_for(ents, player_id, @turn_count)
          if msg
            GameLogger.log("\nsent msg to #{player_id}: #{msg}")
            @network_manager.write(player_id, msg)
          end
        end
        @network_manager.flush!
        # puts "DONE."
      end
    end
  end

  def send_update_to_clients(ents, input)
    # require 'objspace'
    # puts "MEM: #{ObjectSpace.memsize_of(@entity_manager)}"
    # ents.send(:instance_variable_set, '@prev', @entity_manager)
    # ents = @entity_manager.deep_clone
    @data_out_queue << [ents, input]
  end

  def start!
    @start = true
    Prefab.timer(entity_manager: @entity_manager)
  end
  def started?
    @start
  end

  def update(delta:, input:)
    begin
      if @start && !@game_over
        @turn_count ||= 0
        @remaining_steps ||= STEPS_PER_TURN
        msgs = {}
        input[:turn] = @turn_count

        if @remaining_steps == 0
          @remaining_steps = STEPS_PER_TURN
          @turn_count += 1
          @rollover = 1
          @entity_manager = @clone if @clone

          @clone = @entity_manager.deep_clone
          msgs = @network_manager.pop_messages!
          input[:messages] = msgs
          send_update_to_clients(@clone, input)
        end

        input[:messages] = msgs

        @rollover ||= 1
        @rollover += delta
        if @rollover >= SIMULATION_STEP
          (@rollover / SIMULATION_STEP).floor.times do
            next if @remaining_steps <= 0

            @remaining_steps -= 1
            @world.update @entity_manager, SIMULATION_STEP, input, @resources
            input.delete(:messages)
          end
          @rollover %= SIMULATION_STEP
        end

        time_remaining = @entity_manager.first(Timer).get(Timer).ttl
        @game_over = true if time_remaining <= 0
      end
    rescue Exception => ex
      puts ex.inspect
      puts ex.backtrace.inspect
    end
  end

  def generate_message_for(entity_manager, player_id, turn_count)
    tiles = []
    units = []

    time_remaining = entity_manager.first(Timer).get(Timer).ttl
    if time_remaining <= 0
      return {player: player_id, turn: turn_count, time: time_remaining}.to_json
    end

    base_ent = entity_manager.find(Base, Unit, Health, PlayerOwned, Position).select{|ent| ent.get(PlayerOwned).id == player_id}.first

    base_id = base_ent.id
    base_pos = base_ent.get(Position)
    base_unit = base_ent.get(Unit)
    base = base_ent.get(Base)

    tile_info = entity_manager.find(PlayerOwned, TileInfo).
      find{|ent| ent.get(PlayerOwned).id == player_id}.get(TileInfo)

    base_tile_x = (base_pos.x.to_f/TILE_SIZE).floor
    base_tile_y = (base_pos.y.to_f/TILE_SIZE).floor
    map = entity_manager.first(MapInfo).get(MapInfo)

    prev_interesting_tiles = tile_info.interesting_tiles
    interesting_tiles = Set.new
    entity_manager.each_entity(Unit, PlayerOwned, Position, Ranged, ResourceCarrier) do |ent|
      u, player, pos, rang, res_car = ent.components
      if player.id == player_id
        interesting_tiles.merge(TileInfoHelper.tiles_near_unit(tile_info, u, pos, rang))
      end
    end
    tile_info.interesting_tiles = interesting_tiles
    newly_visible_tiles = interesting_tiles - prev_interesting_tiles
    no_longer_visible_tiles = prev_interesting_tiles - interesting_tiles 

    dirty_tiles = TileInfoHelper.dirty_tiles(tile_info)

    ((interesting_tiles & dirty_tiles) | newly_visible_tiles).each do |i,j|
      res = MapInfoHelper.resource_at(map,i,j)
      tile_units = MapInfoHelper.units_at(map,i,j)
      blocked = MapInfoHelper.blocked?(map,i,j)
      tiles << {
        visible: true,
        x: i-base_tile_x,
        y: j-base_tile_y,
        blocked: blocked,
        resources: res,
        units: tile_units.map do |tu|
          ent = entity_manager.find_by_id(tu, Position, PlayerOwned, Unit, Health)
          pid = ent.get(PlayerOwned).id
          pid != player_id ? 
          {
            id: tu,
            x: ent.get(Position).x.round,
            y: ent.get(Position).y.round,
            type: ent.get(Unit).type,
            player_id: pid,
            health: ent.get(Health).points,
          } : nil
        end.compact
      }
    end

    no_longer_visible_tiles.each do |i,j|
      res = MapInfoHelper.resource_at(map,i,j)
      blocked = MapInfoHelper.blocked?(map,i,j)
      tiles << {
        visible: false,
        x: i-base_tile_x,
        y: j-base_tile_y,
      }
    end

    if base_unit.dirty?
      units << { id: base_ent.id, player_id: player_id, 
        x: 0,
        y: 0,
        status: base_unit.status,
        type: base_unit.type,
        resource: base.resource,
        health: base_ent.get(Health).points,
      }
      base_unit.dirty = false
    end

    entity_manager.each_entity(Unit, Health, PlayerOwned, Position) do |ent|
      u, health, player, pos = ent.components
      if u.dirty?
        if player.id == player_id
          res_car_result = entity_manager.find_by_id(ent.id, ResourceCarrier)
          if res_car_result
            res = res_car_result.get(ResourceCarrier).resource
          else
            res = nil
          end
          units << { id: ent.id, player_id: player.id, 
            x: ((pos.x-base_pos.x).to_f/TILE_SIZE).floor, 
            y: ((pos.y-base_pos.y).to_f/TILE_SIZE).floor, 
            status: u.status,
            type: u.type,
            resource: res,
            health: health.points, 
          }
          u.dirty = false
        end
      end
    end
    msg = {unit_updates: units, tile_updates: tiles}
    msg.merge!( player: player_id, turn: turn_count, time: time_remaining)
    msg.to_json
  end

  private

  def load_map!(res, map_name)
    res[:map] = Map.load_from_file(map_name)
  end

  def build_world(clients, map_name)
    @turn_time = 0
    @resources = {}
    load_map! @resources, map_name
    @entity_manager = EntityManager.new
    @network_manager = NetworkManager.new

    clients.each do |c|
      @network_manager.connect(c[:host], c[:port])
    end

    Prefab.map(player_count: clients.size, 
               entity_manager: @entity_manager, 
               resources: @resources)

    @world = World.new [
      CommandSystem.new,
      MovementSystem.new,
      TimerSystem.new,
      TimedSystem.new,
      TimedLevelSystem.new,
      SoundSystem.new,
    ]
    @render_system = RenderSystem.new
  end

end
