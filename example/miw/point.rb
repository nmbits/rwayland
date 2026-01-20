
module MiW
  module PointMixin
    def offset_by(a1, a2 = nil)
      if a2
        self.x += a1
        self.y += a2
      else
        self.x += a1.x
        self.y += a1.y
      end
      self
    end

    def +(other)
      self.dup.offset_by other.x, other.y
    end

    def -(other)
      self.dup.offset_by -other.x, -other.y
    end

    def to_a
      [x, y]
    end
  end

  class Point < Struct.new(:x, :y)
    include PointMixin
  end
end
