require 'gosu'
require 'awesome_print'
require 'json'
require 'easy_diff'
require 'thread'

require_relative 'lib/core_ext'
require_relative 'lib/vec'
require_relative 'components/components'
require_relative 'lib/prefab'
require_relative 'systems/render_system'
require_relative 'systems/systems'
require_relative 'lib/world'
require_relative 'lib/map'
require_relative 'lib/entity_manager'
require_relative 'lib/input_cacher'
require_relative 'lib/network_manager'

ASSETS = {
  dirt1: 'assets/PNG/Default Size/Tile/scifiTile_41.png',
  dirt2: 'assets/PNG/Default Size/Tile/scifiTile_42.png',
  tree1: 'assets/PNG/Default Size/Environment/scifiEnvironment_14.png',
  base1: 'assets/PNG/Default Size/Structure/scifiStructure_01.png',
  worker1: 'assets/PNG/Default Size/Unit/scifiUnit_01.png',
  small_res1: 'assets/PNG/Default Size/Environment/scifiEnvironment_09.png',
  large_res1: 'assets/PNG/Default Size/Environment/scifiEnvironment_10.png',
}

class RtsGame < Gosu::Window
  MAX_UPDATE_SIZE_IN_MILLIS = 500
  TURN_DURATION = 100
  TILE_SIZE = 64
  PLAYER_START_RESOURCE = 100

  DIR_VECS = {
    'N' => vec(0,-1),
    'S' => vec(0,1),
    'W' => vec(-1,0),
    'E' => vec(1,0),
  }

  def initialize
    super(1024,1024,false)
    @input_cacher = InputCacher.new
    @last_millis = Gosu::milliseconds.to_f
    build_world

    @data_out_queue = Queue.new
    @sync_data_out_thread = Thread.new do
      loop do
        ents = @data_out_queue.pop

        @network_manager.clients.each do |player_id|
          msg = generate_message_for(ents, player_id, @turn_count)
          @network_manager.write(player_id, msg)
        end
        @network_manager.flush!
      end
    end
  end

  def needs_cursor?
    true
  end

  def update
    begin
      self.caption = "FPS: #{Gosu.fps} ENTS: #{@entity_manager.num_entities}"

      delta = relative_delta
      input = take_input_snapshot

      if @start
				input[:messages] = @network_manager.pop_messages!
        @turn_count ||= 0
        @turn_time += delta
        if @turn_time > TURN_DURATION
          @turn_count += 1
          @turn_time -= TURN_DURATION
          puts "WARNING! Not making turn time budget" if @turn_time > TURN_DURATION
          @turn_time = 0
          # require 'objspace'
          # puts "MEM: #{ObjectSpace.memsize_of(@entity_manager)}"
          ents = @entity_manager.deep_clone
          ents.send(:instance_variable_set, '@prev', @entity_manager)
          @data_out_queue << ents
        end
      end

      @world.update @entity_manager, delta, input, @resources
    rescue Exception => ex
      puts ex.inspect
      puts ex.backtrace.inspect
    end
  end

  def generate_message_for(entity_manager, player_id, turn_count)
    @state_cache ||= {}
    prev_state = @state_cache[player_id] || {}
    new_state = build_state_for_player(entity_manager, player_id)
    @state_cache[player_id] = new_state
    msg = build_diff_message(prev_state, new_state)
    msg.merge!( player: player_id, turn: turn_count)
    msg.to_json
  end

  def build_state_for_player(entity_manager, player_id)
    units = []
    tiles = []

    base_ent = entity_manager.find(Base, PlayerOwned, Position).select{|ent| ent.components[1].id == player_id}.first
    base_id = base_ent.id
    base_pos = base_ent.get(Position)
    base = base_ent.get(Base)

    tile_info = entity_manager.find(PlayerOwned, TileInfo).
      first{|ent| ent.get(PlayerOwned).id == player_id}.get(TileInfo)

    base_tile_x = (base_pos.x.to_f/TILE_SIZE).floor
    base_tile_y = (base_pos.y.to_f/TILE_SIZE).floor
    map = entity_manager.first(MapInfo).get(MapInfo)

    tile_info.tiles.each do |i, row|
      row.each do |j, v|
        res = MapInfoHelper.resource_at(map,i,j)
				blocked = MapInfoHelper.blocked?(map,i,j)
        tiles << {
          x: i-base_tile_x,
          y: j-base_tile_y,
          blocked: blocked,
          resources: res,
          units: [{
            player_id: 0, 
            x: (i-base_tile_x)*TILE_SIZE,
            y: (j-base_tile_y)*TILE_SIZE,
            type: 'worker'
          }],
        }
      end
    end

    units << { type: :base, id: base_ent.id, player_id: player_id, 
      x: 0, y: 0, resource: base.resource }

    entity_manager.each_entity(Unit, PlayerOwned, Position, ResourceCarrier) do |ent|
      u, player, pos, res_car = ent.components
      if ent.id != base_id
        if player.id == player_id
          units << { id: ent.id, player_id: player.id, 
            x: ((pos.x-base_pos.x).to_f/TILE_SIZE).floor, 
            y: ((pos.y-base_pos.y).to_f/TILE_SIZE).floor, 
            status: u.status,
            resource: res_car.resource
          }
        end
      end
    end
    {units: units, tiles: tiles}
  end

  def build_diff_message(prev_state, new_state)
    # start = Time.now
    rem, diff = prev_state.easy_diff(new_state)
    # puts Time.now-start
    msg = {}
    msg[:unit_updates] = diff[:units] if diff[:units]
    msg[:tile_updates] = diff[:tiles] if diff[:tiles]
    msg
  end

  def draw
    @render_system.draw self, @entity_manager, @resources
  end

  def button_down(id)
    close if id == Gosu::KbEscape
    if @start
      @input_cacher.button_down id
    else
      @start = true
    end
  end

  def button_up(id)
    @input_cacher.button_up id
  end
  private

  def preload_assets!(res)
    images = {}
    images[:dirt1] = Gosu::Image.new(ASSETS[:dirt1], tileable: true)
    images[:dirt2] = Gosu::Image.new(ASSETS[:dirt2], tileable: true)
    ASSETS.each do |name,file|
      images[name] ||= Gosu::Image.new(file)
    end

    # TODO add sounds and music here?
    res[:images] = images
  end

  def load_map!(res)
    # res[:map] = Map.generate(32,32)
    # res[:map] = Map.load_from_file('map.json')
    res[:map] = Map.load_from_file('map.tmx')
  end

  def build_world
    @turn_time = 0
    @resources = {}
    load_map! @resources
    preload_assets! @resources
    @entity_manager = EntityManager.new
    @network_manager = NetworkManager.new
    @network_manager.connect("localhost", "9090")

    Prefab.map(entity_manager: @entity_manager, resources: @resources)

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

  def relative_delta
    total_millis = Gosu::milliseconds.to_f
    delta = total_millis
    delta -= @last_millis if total_millis > @last_millis
    @last_millis = total_millis
    delta = MAX_UPDATE_SIZE_IN_MILLIS if delta > MAX_UPDATE_SIZE_IN_MILLIS
    delta
  end

  def take_input_snapshot
    total_millis = Gosu::milliseconds.to_f

    mouse_pos = {x: mouse_x, y: mouse_y}
    input_snapshot = @input_cacher.snapshot @last_snapshot, total_millis, mouse_pos
    @last_snapshot = input_snapshot
    input_snapshot
  end
end

if $0 == __FILE__
  $window = RtsGame.new
  $window.show
end
