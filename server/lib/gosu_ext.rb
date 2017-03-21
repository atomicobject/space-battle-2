module Gosu
  class Color
    alias hash gl
    def eql?(other)
      gl == other.gl
    end
    def to_s
      "RGBA: #{red}-#{green}-#{blue}-#{alpha}"
    end
    def info
      [red,green,blue,alpha].inspect
    end
  end
end
