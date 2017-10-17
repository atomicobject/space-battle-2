module JsonIvars
  def to_json(*opts)
    {}.tap do |json|
      # json[:klass] = self.class
      instance_variables.each do |var|
        v = instance_variable_get(var)
        json[var[1..-1]] = v unless v.nil?
      end
    end.to_json(*opts)
  end
end

def define_component(opts={})
  attrs = opts[:attrs]
  Class.new do
    include JsonIvars
    if attrs
      attr_accessor *attrs
    end

    def initialize(initial_values={})
      initial_values.each do |k,v|
        instance_variable_set("@#{k}",v)
      end
    end
  end
end
Base = define_component(attrs: [:resource])
Sprited = define_component(attrs: [:image, :flipped, :offset, :scale, :x_scale, :y_scale])
Textured = define_component(attrs: [:image, :x1, :y1, :x2, :y2, :x3, :y3, :x4, :y4])
Animated = define_component(attrs: [:frames, :timings, :index, :loop, :time])
Decorated = define_component(attrs: [:image, :scale, :offset])
PlayerOwned = define_component(attrs: [:id])
PlayerInfo = define_component(attrs: [
  :base_count, :worker_count, :scout_count, :tank_count, 
  :total_units, :kill_count, :total_resources,
  :death_count, :total_commands, :invalid_commands
])
Health = define_component(attrs: [:points, :max])
EntityTarget = define_component(attrs: [:id])
Resource = define_component(attrs: [:value, :total])
Timed = define_component(attrs: [:accumulated_time_in_ms])
Ranged = define_component(attrs: [:distance])
Speed = define_component(attrs: [:speed])
Attack = define_component(attrs: [:damage,:range,:cooldown,:current_cooldown,:can_attack])

ShootCommand = define_component(attrs: [:id,:dx,:dy])
MeleeCommand = define_component(attrs: [:id,:target])
Shooter = define_component
Melee = define_component
MeleeEffect = define_component

MovementCommand = define_component(attrs: [:target_vec])
CreateCommand = define_component(attrs: [:type, :build_time])
SoundEffectEvent = define_component(attrs: [:sound_to_play])

Named = define_component(attrs: [:name])

MusicInfo = define_component(attrs: [:mood, :battle, :peace, :peace_timer, :peace_music])

class TileInfo
  include JsonIvars
  attr_accessor :dirty_tiles, :interesting_tiles, :seen_tiles 
  def initialize
    @dirty_tiles = Set.new
    @interesting_tiles = Set.new
    @seen_tiles = {}
  end

  def to_json(*opts)
    json = {}
    json["dirty_tiles"] = @dirty_tiles.to_a unless @dirty_tiles.empty?
    json["interesting_tiles"] = @interesting_tiles.to_a unless @interesting_tiles.empty?
    json.to_json(*opts)
  end
end

class MapInfo
  include JsonIvars
  attr_accessor :tiles, :width, :height
  def initialize(width, height)
    @width = width
    @height = height
    @tiles = {}
  end

  def to_json(*opts)
    non_empty_tiles = {}
    @tiles.each do |y, col|
      col.each do |x, t|
        if t.blocked || t.units.size > 0 || t.resource || t.objects.size > 0
          non_empty_tiles[y] ||= {}
          non_empty_tiles[y][x] = t
        end
      end
    end
    {
      "width" => @width,
      "height" => @height,
      "tiles" => non_empty_tiles
    }.to_json(*opts)
  end
end

class Unit
  include JsonIvars
  attr_accessor :status, :dirty, :type
  def initialize(status: :idle, type: :worker)
    @status = status
    @dirty = true
    @type = type
    @alive = true
  end
  def dirty?
    @dirty
  end
end
class ResourceCarrier
  include JsonIvars
  attr_accessor :resource
  def initialize
    @resource = 0
  end
end
class Position
  include JsonIvars
  attr_accessor :x, :y, :z, :tile_x, :tile_y, :rotation
  def initialize(x:,y:,rotation:0,tile_x:nil,tile_y:nil,z:2)
    @x = x
    @y = y
    @z = z
    @tile_x = tile_x
    @tile_y = tile_y
    @rotation = 0
  end

  def to_vec
    vec(@x, @y)
  end
end
class TilePosition < Position
  include JsonIvars
end

class Velocity < Vec
  include JsonIvars
end

class Label
  include JsonIvars
  attr_accessor :text, :size, :font
  def initialize(size:,text:"",font:nil)
    @size = size
    @font = font
    @text = text
  end
end

class LevelTimer
  include JsonIvars
end
class Timer
  include JsonIvars
  attr_accessor :ttl, :repeat, :total, :event, :name, :expires_at, :keep
  def initialize(name, ttl, repeat=false, event = nil)
    @name = name
    @total = ttl
    @ttl = ttl
    @repeat = repeat
    @event = event
  end
end

class DeathEvent
  include JsonIvars
end
