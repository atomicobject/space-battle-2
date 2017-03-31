class TileInfo
  attr_accessor :tiles
  def initialize
    @tiles = Hash.new do |h, k| 
      h[k] = {}
    end
  end

end

class MovementCommand
  attr_accessor :target_vec
  def initialize(target_vec:)
    @target_vec = target_vec
  end
end

class Unit
  attr_accessor :status
  def initialize(status: :idle)
    @status = status
  end
end
class Base
end
class Sprited
  attr_accessor :image
  def initialize(image:)
    @image = image
  end
end

class PlayerOwned
  attr_accessor :id
  def initialize(id:)
    @id = id
  end
end
class Health
  attr_accessor :points
  def initialize(points:)
    @points = points
  end
end

class EntityTarget
  attr_accessor :id
  def initialize(id)
    @id = id
  end
end

class Position
  attr_accessor :x, :y, :z
  def initialize(x:,y:,z:2)
    @x = x
    @y = y
    @z = z
  end

  def to_vec
    vec(@x, @y)
  end
end

class Velocity < Vec
end

class LevelTimer; end
class Timed
  attr_accessor :accumulated_time_in_ms

  def initialize
    @accumulated_time_in_ms = 0
  end
end

class Label
  attr_accessor :text, :size, :font
  def initialize(size:,text:"",font:nil)
    @size = size
    @font = font
    @text = text
  end
end

class Timer
  attr_accessor :ttl, :repeat, :total, :event, :name, :expires_at
  def initialize(name, ttl, repeat, event = nil)
    @name = name
    @total = ttl
    @ttl = ttl
    @repeat = repeat
    @event = event
  end
end

class SoundEffectEvent
  attr_accessor :sound_to_play
  def initialize(sound_to_play)
    @sound_to_play = sound_to_play
  end
end
