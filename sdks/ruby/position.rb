class Position
  attr_accessor :x, :y
  def initialize(x, y)
    @x = x
    @y = y
  end
end

def pos(x, y)
  Position.new(x, y)
end
