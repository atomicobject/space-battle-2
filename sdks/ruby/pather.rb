# Ideal choice of fixed-point equivalent to 1.0 that can almost perfectly represent sqrt(2) and (sqrt(2) - 1) in whole numbers
# 1.000000000 = 2378
# 0.414213624 = 985 / 2378
# 1.414213625 = 3363 / 2378
# 1.414213562 = Actual sqrt(2)
# 0.00000006252 = Difference between actual sqrt(2) and fixed-point sqrt(2)
COST_STRAIGHT = 2378
COST_DIAG = 3363

class Node
  include Comparable

  attr_accessor :location, :cost, :dist, :estimated_total, :parent, :state
  def initialize(location:,cost:,dist:,estimated_total:,parent:nil)
    @location = location
    @cost = cost
    @dist = dist
    @estimated_total = estimated_total
    @parent = parent
  end

  def <=>(b)
    a = self
    if a.estimated_total < b.estimated_total
      return -1
    elsif a.estimated_total > b.estimated_total
      return 1
    else
      0
    end
  end

  def ==(other)
    return false if other.nil? || !other.is_a?(Node)
    @location == other.location
  end
end

NEIGHBORS = [
  [1,0,COST_STRAIGHT],
  [-1,0,COST_STRAIGHT],
  [0,1,COST_STRAIGHT],
  [0,-1,COST_STRAIGHT], 
  # [1,1,COST_DIAG], 
  # [1,-1,COST_DIAG],
  # [-1,1,COST_DIAG],
  # [-1,-1,COST_DIAG],
]
class UnsortedPriorityQueue
  def initialize
    @array = []
  end
  def <<(item)
    @array << item
  end
  def include?(item)
    @array.include? item
  end
  def empty?
    @array.empty?
  end
  def pop_smallest
    @array.delete @array.min_by(&:estimated_total)
  end
end

class AStar
  class << self
    def find_path(board, from, to)
      h = board.size
      w = board.first.size
      nodes = {}

      open = UnsortedPriorityQueue.new
      fast_stack = []

      dist = heuristic(from, to)
      node = Node.new(location: from, cost: 0, dist: dist, estimated_total: dist)
      open << node 

      until (fast_stack.empty? && open.empty?)
        current = fast_stack.pop
        current ||= open.pop_smallest

        nodes[current.location] ||= current

        if current.location == to
          return nodes, build_path(current)
        else
          current.state = :closed

          NEIGHBORS.each do |dx,dy,travel_cost|
            n_loc = [current.location[0]+dx, current.location[1]+dy]
            next if blocked?(board, n_loc)

            n_node = nodes[n_loc]
            next if n_node && n_node.state == :closed

            dist = heuristic(n_loc, to)
            cost = current.cost + travel_cost
            estimated_total = cost + dist

            if n_node
              n_node = nodes[n_loc]
              next if estimated_total >= n_node.estimated_total

              n_node.cost = cost
              n_node.estimated_total = estimated_total
              n_node.parent = current
            else 
              n_node = Node.new(location: n_loc, cost: cost, dist: dist, 
                                estimated_total: estimated_total, parent: current)
              nodes[n_node.location] = n_node

              n_node.state = :open
              if n_node.estimated_total <= current.estimated_total
                fast_stack << n_node
              else
                open << n_node
              end
            end

          end
        end
      end

      return nodes, nil
    end

    def build_path(node)
      [].tap do |path|
        while node.parent
          path.unshift node.location
          node = node.parent
        end
      end
    end

    def blocked?(board, loc)
      loc[1] > (board.size-1) || loc[1] < 0 ||
        loc[0] > (board[0].size-1) ||  loc[0] < 0 ||
        board[loc[1]][loc[0]] > 0
    end

    def heuristic(from, to)
      dx = (to[0]-from[0]).abs
      dy = (to[1]-from[1]).abs
      COST_STRAIGHT * (dx + dy) + (COST_DIAG - 2 * COST_STRAIGHT) * min(dx,dy)
    end

    def max(a,b)
      a < b ? b : a
    end

    def min(a,b)
      a > b ? b : a
    end

  end
end
