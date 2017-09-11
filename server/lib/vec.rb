# terrible vector class  =P
def vec(x=0,y=0)
  Vec.new(x:x,y:y)
end
class Vec
  attr_accessor :x, :y

  def initialize(x:0,y:0)
    @x = x
    @y = y
  end

  def abs()
    vec(x.abs, y.abs)
  end

  def +(other)
    vec(x+other.x,y+other.y)
  end

  def -(other)
    vec(x-other.x,y-other.y)
  end

  def *(scale)
    vec(x*scale,y*scale)
  end

  def closest_cardinal()
    abs_vec = abs()
    if abs_vec.x >= abs_vec.y
      if abs_vec.x == 0
        vec(0, 0)
      else
        vec(x / abs_vec.x, 0)
      end
    else
      if abs_vec.y == 0
        vec(0, 0)
      else
        vec(0, y / abs_vec.y)
      end
    end
  end

  def rotate()
    vec(y, -x)
  end

  def magnitude
    Math.sqrt(@x*@x + @y*@y)
  end

  def clip_to(max_magnitude)
    mag = magnitude
    if mag > max_magnitude
      self * (max_magnitude / mag)
    else
      self
    end
  end

  def move_toward(pos, distance)
    displacement = self - pos
    if displacement.magnitude >= distance
      pos
    else
      self + (displacement.unit * distance)
    end
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

end
