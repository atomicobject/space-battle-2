require 'tmx'
class Resource
  attr_accessor :value, :total
  def initialize(value:, total:)
    @value = value
    @total = total
  end
end

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
    return nil if x < 0 || x > @width-1 || y < 0 || y > @height-1
    @tiles[x][y]
  end

  def self.load_from_file(file_name)
    raise "Cannot load map from #{file_name}. File not found" unless File.exists? file_name
    tmx = Tmx.load(file_name)

    tileset_image = tmx.tilesets.first.image
    tile_size = tmx.tilesets.first.tilewidth
    layers = tmx.layers.group_by(&:name)
    terrain = layers["terrain"].first
    environment = layers["environment"].first
    w = tmx["width"]
    h = tmx["height"]
    # %w(terrain environment objects).map
    # map_data.tile_grid[0].size

    Map.new(w,h).tap do |m|
			environment.data.each.with_index do |tile_id, i|
				x = i % environment.width
				y = i / environment.width

				# tile = new_tile_for_index(tile_id, x,y)

        resource_ids = [78,112,94,113]
				m.at(x,y).resource = Resource.new(value: 50, total: 2000) if resource_ids.include?(tile_id)
				m.at(x,y).blocked = tile_id != 0
			end
    end
  end

  def self.generate(w,h)
    Map.new(w,h).tap do |m|
      # m.at(0,0).objects << Tree.new
      # m.at(6,6).objects << Tree.new
    end
  end

  def blocked?(x,y)
    tile = at(x,y)
    tile.nil? || tile.blocked?
  end

  def resource_at(x,y)
    tile = at(x,y)
    tile && tile.resource
  end
end

class Tile
  TYPES = [:dirt]
  WALKABLE_TYPES = [:dirt]
  attr_accessor :objects, :units, :type, :blocked, :resource
  def initialize(type = :dirt)
    @type = type
    @objects = []
    @units = []
  end

  def blocked?
    @blocked
  end

  def image
    @image ||= [:dirt1, :dirt2].sample
  end
  
  def walkable?
    WALKABLE_TYPES.include? @type && @objects.empty? # assume all objects block for now
  end
end
