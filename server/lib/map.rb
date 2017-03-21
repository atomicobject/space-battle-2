class Map
  attr_reader :width, :height
  def initialize(w,h)
    @width = w
    @height = h
    @tiles = Hash.new do |h,k|
      h[k] = Hash.new do |hh,kk|
        hh[kk] = Tile.new
      end
    end
  end

  def at(x,y)
    @tiles[x][y]
  end

  def self.generate(w,h)
    Map.new(w,h).tap do |m|
      # m.at(0,0).objects << Tree.new
      # m.at(6,6).objects << Tree.new
    end
  end
end

class Tile
  TYPES = [:dirt]
  WALKABLE_TYPES = [:dirt]
  attr_accessor :objects, :units, :type
  def initialize(type = :dirt)
    @type = type
    @objects = []
    @units = []
  end

  def image
    @image ||= [:dirt1, :dirt2].sample
  end
  
  def walkable?
    WALKABLE_TYPES.include? @type && @objects.empty? # assume all objects block for now
  end
end
