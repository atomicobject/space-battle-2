require 'tmx'

class TileInfoHelper
  class << self
    def tiles_near_unit(tile_info, u, pos)
      tiles = Set.new
      range = 3
      x = pos.x
      y = pos.y
      tile_size = RtsGame::TILE_SIZE

      tile_x = (x.to_f/tile_size).floor
      tile_y = (y.to_f/tile_size).floor

      ((tile_x-range)..(tile_x+range)).each do |x|
        ((tile_y-range)..(tile_y+range)).each do |y|
          tiles << [x,y]
        end
      end
      tiles
    end

    # these are tiles who's occupants or resources have changed
    def dirty_tile(tile_info, x, y)
      tile_info.dirty_tiles << [x,y]
    end

    def dirty_tiles(tile_info)
      tile_info.dirty_tiles = Set.new
    end
  end
end

class MapInfoHelper
  class << self
    def blocked?(info, x, y)
      tile = at(info, x, y)
      tile.nil? || tile.blocked?
    end

    def init_at(info,x,y,static_tile_info)
      info.tiles[x][y] = static_tile_info
    end

    def at(info,x,y)
      return nil if x < 0 || x > info.width-1 || y < 0 || y > info.height-1
      info.tiles[x][y]
    end

    def remove_resource_at(info,x,y)
      add_resource_at(info,x,y,nil)
    end

    def add_resource_at(info,x,y,res)
      tile = at(info,x,y)
      if tile
        tile.resource = res
      else
        puts "WARNING: trying to place a resource off the map"
      end
    end

    def resource_at(info,x,y)
      tile = at(info, x, y)
      tile && tile.resource
    end
  end
end

class Map
  attr_reader :width, :height, :tiles, :objects

  RESOURCE_IDS = [78,112,94,113]
  TYPE_FOR_TILE_INDEX = {
    0 => :dirt,
    21 => :tree1,
    22 => :tree2,
    38 => :tree4,
    39 => :tree5,
    40 => :tree6,
  }

  def initialize(w,h, objects)
    @objects = objects
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
    objects = tmx.objects

    terrain = layers["terrain"].first
    environment = layers["environment"].first
    blocked = layers["blocked"].first
    w = tmx["width"]
    h = tmx["height"]
    # %w(terrain environment objects).map
    # map_data.tile_grid[0].size

    Map.new(w,h,objects).tap do |m|
			blocked.data.each.with_index do |tile_id, i|
				x = i % environment.width
				y = i / environment.width

				# tile = new_tile_for_index(tile_id, x,y)
				m.at(x,y).blocked = tile_id != 0
			end

			environment.data.each.with_index do |tile_id, i|
				x = i % environment.width
				y = i / environment.width

				# tile = new_tile_for_index(tile_id, x,y)
        type = TYPE_FOR_TILE_INDEX[tile_id]
        puts "unknown tile id: #{tile_id}" unless type
				m.at(x,y).type = type if type
			end
    end
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
  attr_accessor :objects, :units, :type, :blocked, :resource
  def initialize(type = :dirt)
    @type = type
    @objects = []
    @units = []
  end

  def blocked?
    @blocked || @resource
  end

  def image
    @image ||= (@type.nil? || @type == :dirt) ? [:dirt1, :dirt2].sample : @type
  end

  def walkable?
    WALKABLE_TYPES.include? @type && @objects.empty? # assume all objects block for now
  end
end
