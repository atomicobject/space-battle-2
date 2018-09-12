require_relative 'position'
# require_relative "custom_pather"
# class CustomPather
#   def path_from(...)
#     Pather.find...
#   end
# end

class RandomStrategy
  MOVE_DIRECTIONS = %w[N S W E].freeze
  DIRECTION_VECTORS = {
    'N' => pos(0, -1),
    'S' => pos(0, 1),
    'W' => pos(-1, 0),
    'E' => pos(1, 0),
  }
  VECTOR_DIRECTIONS = {
    [0,-1] => ['N'],
    [0,1] => ['S'],
    [-1,0] => ['W'],
    [1,0] => ['E'],
    [1,1] => ['S','E'],
    [-1,1] => ['S', 'W'],
    [1,-1] => ['N', 'E'],
    [-1,-1] => ['N', 'W'],
  }

  def initialize(world)
    @world = world
  end

  # may return nil if not adjacent
  def dir_from_points(x1, y1, x2, y2)
    VECTOR_DIRECTIONS[[x2-x1, y2-y1]].first
  end

  def commands
    # TODO: use pather to figure out paths
    cmds = []
    # tell all idle units to move randomly
    @world.units.select(&:idle?).each do |unit|
      res_tile = adjacent_resource_client_tile(unit, @world)
      if (unit.resource.nil? || unit.resource <= 0) && res_tile && res_tile.resource
        direction = dir_from_points(unit.x, unit.y, res_tile.x, res_tile.y)
        cmds << CommandBuilder.gather(unit, direction)
      else
        cmds << CommandBuilder.move(unit, MOVE_DIRECTIONS.sample)
      end
    end
    cmds
  end

  def adjacent_resource_client_tile(unit, world)
    # require 'pry'
    # binding.pry
    DIRECTION_VECTORS.values.each do |dv|
      client_tile = world.get(unit.x + dv.x, unit.y + dv.y)
      return client_tile if client_tile&.resource
    end
    nil
  end
end
