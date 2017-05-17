# require 'awesome_print'
require 'json'
require 'thread'
require 'set'

require_relative '../lib/core_ext'
require_relative '../lib/vec'
require_relative '../components/components'
require_relative '../systems/render_system'
require_relative '../systems/systems'
require_relative '../lib/world'
require_relative '../lib/map'
require_relative '../lib/entity_manager'
require_relative '../lib/input_cacher'
require_relative '../src/network_manager'
require_relative '../src/prefab'

class GameLogger
  require 'singleton'
  include Singleton
  def initialize
    @log_file = File.open('game-log.txt', 'w+')
  end
  def log(msg)
    @log_file.puts(msg)
    @log_file.flush
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
  STARTING_WORKERS = 10
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
      attack_type: :melee,
      attack_cooldown: 2 * STEPS_PER_TURN,
      hp: 5,
      can_carry: true,
    },
    scout: {
      cost: 130,
      range: 5,
      speed: 2,
      attack: 1,
      attack_type: :melee,
      attack_cooldown: 2 * STEPS_PER_TURN,
      hp: 3,
    },
    tank: {
      cost: 150,
      range: 2,
      speed: 0.5,
      attack: 4,
      hp: 10,
      attack_type: :ranged,
      attack_cooldown: 5 * STEPS_PER_TURN,
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

  def start_sim_thread(initial_state, input_queue, output_queue)
    t = Thread.new do
      ents = initial_state
      turn_count = 0

      loop do
        input = input_queue.pop

        input[:messages] && input[:messages].each do |msg|
          GameLogger.log("\nreceived msg from #{msg.connection_id}: #{msg.data}")
        end
        STEPS_PER_TURN.times do
          @world.update ents, SIMULATION_STEP, input, nil
          input.delete(:messages)
        end
        @network_manager.clients.each do |player_id|
          msg = generate_message_for(ents, player_id, turn_count)
          if msg
            GameLogger.log("\nsent msg to #{player_id}: #{msg}")
            @network_manager.write(player_id, msg)
          end
        end
        @network_manager.flush!

        output_queue << ents.deep_clone

        turn_count += 1
        # puts "DONE."
      end
    end
    return t
  end

  def initialize(map:,clients:)
    build_world clients, map
    @next_turn_queue = Queue.new
    @data_out_queue = Queue.new
    @messages_queue ||= Queue.new
  end

  def send_update_to_clients(input)
    # require 'objspace'
    # puts "MEM: #{ObjectSpace.memsize_of(@entity_manager)}"
    # ents.send(:instance_variable_set, '@prev', @entity_manager)
    # ents = @entity_manager.deep_clone
    @data_out_queue << input
    true
  end

  def start!
    @start = true
    Prefab.timer(entity_manager: @entity_manager)
    start_sim_thread(@entity_manager.deep_clone, @data_out_queue, @next_turn_queue)
  end

  def started?
    @start
  end

  def update(delta:, input:)
    begin
      if @start && !@game_over

        @bla ||= send_update_to_clients(input)

        @turn_time ||= 0
        @turn_time += delta
        @sim_steps ||= 0
        if @sim_steps >= STEPS_PER_TURN
          @sim_steps =0
          msgs = @network_manager.pop_messages!
          input[:messages] = msgs

          send_update_to_clients(input.deep_clone)
          @entity_manager = @next_turn_queue.pop

          @turn_time -= TURN_DURATION
        else
          input[:messages] = []
        end

        while (@sim_steps * SIMULATION_STEP <= @turn_time) && (@sim_steps < STEPS_PER_TURN)
          @world.update @entity_manager, SIMULATION_STEP, input, @resources
          input.delete(:messages)
          @sim_steps+=1
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

    map = entity_manager.first(MapInfo).get(MapInfo)

    prev_interesting_tiles = tile_info.interesting_tiles
    interesting_tiles = Set.new
    entity_manager.each_entity(Unit, PlayerOwned, Position, Ranged) do |ent|
      u, player, pos, rang = ent.components
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
        x: i-base_pos.tile_x,
        y: j-base_pos.tile_y,
        blocked: blocked,
        resources: res,
        units: tile_units.map do |tu|
          ent = entity_manager.find_by_id(tu, Position, PlayerOwned, Unit, Health)
          pid = ent.get(PlayerOwned).id
          status = ent.get(Unit).status == :dead ? :dead : :unknown
          pid != player_id ? 
          {
            id: tu,
            x: ent.get(Position).tile_x,
            y: ent.get(Position).tile_y,
            type: ent.get(Unit).type,
            status: status,
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
        x: i-base_pos.tile_x,
        y: j-base_pos.tile_y,
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
          res = res_car_result&.get(ResourceCarrier)&.resource

          attack_res = entity_manager.find_by_id(ent.id, Attack)
          can_attack = attack_res&.get(Attack)&.can_attack

          units << { id: ent.id, player_id: player.id, 
            x: (pos.tile_x-base_pos.tile_x),
            y: (pos.tile_y-base_pos.tile_y),
            status: u.status,
            type: u.type,
            resource: res,
            health: health.points, 
            can_attack: can_attack,
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
      AttackSystem.new,
      MovementSystem.new,
      TimerSystem.new,
      TimedSystem.new,
      TimedLevelSystem.new,
      SoundSystem.new,
    ]
    @render_system = RenderSystem.new
  end

end
