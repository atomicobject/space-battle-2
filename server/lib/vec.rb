# terrible vector class  =P
def vec(x,y)
  Vec.new(x:x,y:y)
end
class Vec
  attr_accessor :x, :y

  def initialize(x:0,y:0)
    @x = x
    @y = y
  end

  def +(other)
    vec(x+other.x,y+other.y)
  end

  def -(other)
    vec(x-other.x,y-other.y)
  end

  def magnitude
    Math.sqrt(@x*@x + @y*@y)
  end

  def unit
    m = Math.sqrt(x*x+y*y)
    vec(x/m, y/m)
  end

  def to_s
    "Vec: [#{x},#{y}]"
  end

  alias_method :inspect, :to_s

  def ==(other)
    self.class == other.class and @x == other.x and @y == other.y
  end

  alias_method :eql?, :==

  def hash
    @x.hash + @y.hash
  end


  UP = vec(0,-1)
  RIGHT = vec(1,0)
  DOWN = vec(0,1)
  LEFT = vec(-1,0)

  NEIGHBOR_VECS = [
    Vec::RIGHT,
    Vec::UP,
    Vec::DOWN,
    Vec::LEFT,
  ]

end
