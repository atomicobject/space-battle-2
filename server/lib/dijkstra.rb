
module Dijkstra
  def find_path(from, to, &get_neighbors)
    return [] if from == to
    open = get_neighbors.call(from)
    closed = []
    parent_lookup = {}

    while current_location = open.pop
      if current_location == to
        return build_path(parent_lookup, current_location)
      else
        closed << current_location
        unvisited_neighbors = get_neighbors.call(current_location) - closed
        unvisited_neighbors.each do |n|
          parent_lookup[n] = current_location
        end
        open.concat(unvisited_neighbors)
      end
    end

    return nil
  end

  def build_path(parent_lookup, location)
    path = [location]
    while location = parent_lookup[location]
      path << location
    end
    return path.reverse
  end
  module_function :find_path, :build_path
end



