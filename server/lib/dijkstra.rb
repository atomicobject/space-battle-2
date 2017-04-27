
module Dijkstra
  def find_path(from, to, &get_neighbors)
    return [] if from == to
    open = [from]
    #get_neighbors.call(from)
    closed = []
    cost_lookup = { from => 0 }
    parent_lookup = {}

    while current_location = open.shift
      if current_location == to
        return build_path(parent_lookup, current_location).drop(1)
      else
        closed << current_location
        unvisited_neighbors = get_neighbors.call(current_location) - closed - open
        # puts unvisited_neighbors
        unvisited_neighbors.each do |n|
          parent_lookup[n] = current_location
          current_cost = cost_lookup[current_location]
          cost_lookup[n] = current_cost + 1
        end
        open.concat(unvisited_neighbors)
      end
      open.sort_by! do |a|
        cost_lookup[a]
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



