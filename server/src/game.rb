# require 'awesome_print'
require 'json'
require 'oj'
require 'thread'
require 'set'
require 'drb/drb'

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
    @log_file.puts msg
    @log_file.flush
  end

  def self.log_game_state(em)
    instance.log({time: Time.now.to_ms, type: :game_state, state: em.id_to_comp}.to_json)
  end

  def self.log_connection(pid, host, port)
    instance.log({time: Time.now.to_ms, type: :connection, id: pid, host: host, port: port}.to_json)
  end

  def self.log_sent(pid, data)
    instance.log({time: Time.now.to_ms, type: :to_player, id: pid, msg: data}.to_json)
  end

  def self.log_received(pid, data)
    instance.log({time: Time.now.to_ms, type: :from_player, id: pid, msg: data}.to_json)
  end
end


class RtsGame
  ASSETS = {
    dirt1: 'assets/PNG/Default size/Tile/scifiTile_41.png',
    dirt2: 'assets/PNG/Default size/Tile/scifiTile_42.png',
    tree1: 'assets/PNG/Default size/Tile/scifiTile_15.png',
    tree2: 'assets/PNG/Default size/Tile/scifiTile_16.png',
    tree3: 'assets/PNG/Default size/Tile/scifiTile_27.png',
    tree4: 'assets/PNG/Default size/Tile/scifiTile_28.png',
    tree5: 'assets/PNG/Default size/Tile/scifiTile_29.png',
    tree6: 'assets/PNG/Default size/Tile/scifiTile_30.png',
    base0: 'assets/PNG/Retina/Structure/scifiStructure_11.png',
    worker0: 'assets/PNG/Retina/Unit/scifiUnit_01.png',
    scout0: 'assets/PNG/Retina/Unit/scifiUnit_05.png',
    tank0: 'assets/PNG/Retina/Unit/scifiUnit_08.png',
    base1: 'assets/PNG/Retina/Structure/scifiStructure_06.png',
    worker1: 'assets/PNG/Retina/Unit/scifiUnit_13.png',
    scout1: 'assets/PNG/Retina/Unit/scifiUnit_17.png',
    tank1: 'assets/PNG/Retina/Unit/scifiUnit_20.png',
    small_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_14.png',
    large_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_15.png',
  }

  MAX_UPDATE_SIZE_IN_MILLIS = 500
  TURN_DURATION = 200
  TILE_SIZE = 64
  SIMULATION_STEP = 20
  STEPS_PER_TURN = TURN_DURATION / SIMULATION_STEP
  STARTING_WORKERS = 6
  GAME_LENGTH_IN_MS = 300_000
  UNITS = {
    base: {
      hp: 50,
      range: 2,
    },
    worker: {
      cost: 100,
      hp: 10,
      range: 2,
      speed: 1,
      attack: 2,
      attack_type: :melee,
      attack_cooldown: 3 * STEPS_PER_TURN,
      can_carry: true,
      create_time: 5 * STEPS_PER_TURN,
    },
    scout: {
      cost: 130,
      hp: 5,
      range: 5,
      speed: 2,
      attack: 1,
      attack_type: :melee,
      attack_cooldown: 3 * STEPS_PER_TURN,
      create_time: 10 * STEPS_PER_TURN,
    },
    tank: {
      cost: 150,
      hp: 20,
      range: 2,
      speed: 0.5,
      attack: 4,
      attack_type: :ranged,
      attack_cooldown: 5 * STEPS_PER_TURN,
      create_time: 15 * STEPS_PER_TURN,
    },
  }
  PLAYER_START_RESOURCE = UNITS[:tank][:cost] * 5

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
      step_count = 0
      msgs = []
      loop do
        
        msgs.each do |msg|
          GameLogger.log_received(msg.connection_id, msg.data)
        end
        STEPS_PER_TURN.times do |i|
          total_time = step_count * RtsGame::SIMULATION_STEP
          input = InputSnapshot.new(nil, total_time)
          input[:messages] = msgs if i == 0 
          @world.update ents, SIMULATION_STEP, input, nil
          step_count += 1
        end

        GameLogger.log_game_state(entity_manager)

        time_remaining = ents.first(Timer).get(Timer).ttl
        if time_remaining <= 0
          puts "GAME OVER!"
          @game_over = true 
        end

        @network_manager.clients.each do |player_id|
          msg = generate_message_for(ents, player_id, turn_count)
          if msg
            GameLogger.log_sent(player_id, msg)
            @network_manager.write(player_id, msg)
          end
        end
        @network_manager.flush!

        output_queue << [ents.deep_clone, msgs]

        turn_count += 1
        msgs = input_queue.pop
      end
    end
    return t
  end

  def game_over?
    @game_over
  end

  def winner
    max_score = -999
    max_player = nil
    scores.each do |id, score|
      if score > max_score
        max_score = score
        max_player = id
      end
    end
    max_player
  end

  def scores
    player_scores = {}
    # TODO add other stats... units created/killed/harvested/commands sent?
    @entity_manager.each_entity(Base, PlayerOwned) do |ent|
      b,owner = ent.components
      player_scores[owner.id] = b.resource
    end
    player_scores
  end

  include DRb::DRbUndumped
  attr_reader :input_queue, :next_turn_queue
  def initialize(map:,clients:,fast:false,time:,drb_port:nil)
    build_world clients, map
    @fast_mode = fast
    @time = time
    @input_queue = Queue.new
    @next_turn_queue = Queue.new
    if drb_port
      @drb = DRb.start_service("druby://localhost:#{drb_port}", self)
      puts 'DRB STARTED!!!'
    end
  end

  def start!
    @start = true
    Prefab.timer(entity_manager: @entity_manager, time: @time)
    # unless @drb
      start_sim_thread(@entity_manager.deep_clone, @input_queue, @next_turn_queue)
    # end
    nil
  end

  def started?
    @start
  end

  def update(delta:, input:)
    begin
      if @start && !@game_over
        if @fast_mode
          @input_queue << @network_manager.pop_messages_with_timeout!(RtsGame::TURN_DURATION.to_f / 1000.0)
          @entity_manager, _ = @next_turn_queue.pop
        else
          @turn_time ||= 0
          @turn_time += delta
          @sim_steps ||= 0

          while (@sim_steps * SIMULATION_STEP <= @turn_time) && (@sim_steps < STEPS_PER_TURN)
            input[:messages] = @input_msgs if @input_msgs
            @world.update @entity_manager, SIMULATION_STEP, input, @resources
            input.delete(:messages)
            @input_msgs = nil
            @sim_steps+=1
          end

          if @sim_steps >= STEPS_PER_TURN
            @sim_steps = 0
            @input_queue << @network_manager.pop_messages_with_timeout!(0.0)
            # if everything goes well, the following line should have no effect.
            @entity_manager = @next_entity_manager if @next_entity_manager
            @next_entity_manager, msgs = @next_turn_queue.pop
            @input_msgs = msgs
            @turn_time -= TURN_DURATION
          end
        end
      end
    rescue StandardError => ex
      puts ex.inspect
      puts ex.backtrace.inspect
      raise ex
    end
  end

  def generate_message_for(entity_manager, player_id, turn_count)
    tiles = []
    units = []

    time_remaining = entity_manager.first(Timer).get(Timer).ttl
    if time_remaining <= 0
      return Oj.dump({player: player_id, turn: turn_count, time: time_remaining}, mode: :compat)
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
      if player.id == player_id && u.status != 'dead'
        interesting_tiles.merge(TileInfoHelper.tiles_near_unit(tile_info, u, pos, rang))
      end
    end
    tile_info.interesting_tiles = interesting_tiles
    newly_visible_tiles = interesting_tiles - prev_interesting_tiles
    no_longer_visible_tiles = prev_interesting_tiles - interesting_tiles 

    dirty_tiles = TileInfoHelper.dirty_tiles(tile_info)

    ((interesting_tiles & dirty_tiles) | newly_visible_tiles).each do |i,j|
      res = MapInfoHelper.resource_at(map,i,j)
      resource_ent = entity_manager.find_by_id(res[:id], Resource, Label) if res
      tile_res = nil
      if resource_ent
        tile_res = {
          id: resource_ent.id,
          type: res[:type],
          total: resource_ent.get(Resource).total,
          value: resource_ent.get(Resource).value,
        }
      end

      tile_units = MapInfoHelper.units_at(map,i,j)
      blocked = MapInfoHelper.blocked?(map,i,j)
      tiles << {
        visible: true,
        x: i-base_pos.tile_x,
        y: j-base_pos.tile_y,
        blocked: blocked,
        resources: tile_res,
        units: tile_units.map do |tu|
          ent = entity_manager.find_by_id(tu, Position, PlayerOwned, Unit, Health)
          pid = ent.get(PlayerOwned).id
          status = ent.get(Unit).status == :dead ? :dead : :unknown
          pid != player_id ? 
          {
            id: tu,
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

          unit_info = { id: ent.id, player_id: player.id, 
            x: (pos.tile_x-base_pos.tile_x),
            y: (pos.tile_y-base_pos.tile_y),
            status: u.status,
            type: u.type,
            health: health.points, 
            can_attack: can_attack,
          }
          unit_info[:resource] = res if res
          units << unit_info
          u.dirty = false
        end
      end
    end
    msg = {unit_updates: units, tile_updates: tiles}
    msg.merge!( player: player_id, turn: turn_count, time: time_remaining)
    Oj.dump(msg, mode: :compat)
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
      CreateSystem.new,
      TimerSystem.new,
      TimedSystem.new,
      TimedLevelSystem.new,
      SoundSystem.new,
    ]
    @render_system = RenderSystem.new
  end

end
