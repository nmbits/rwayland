
require 'miw/point'

module MiW
  module RectangleMixin
    def left;   x end
    def top;    y end
    def right;  x + width end
    def bottom; y + height end

    def left_top;     Point.new left,  top    end
    def left_bottom;  Point.new left,  bottom end
    def right_top;    Point.new right, top    end
    def right_bottom; Point.new right, bottom end

    def [](key)
      case key
      when String, Symbol
        self.__send__ key.to_sym
      else
        super
      end
    end

    def []=(key, value)
      case key
      when String, Symbol
        sym = "#{key}=".to_sym
        self.__send__ sym, value
      else
        super
      end
    end
    
    def valid?
      width >= 0 && height >= 0
    end

    def hit_test(x, y)
      ix = (x < self.x ? 0 : (x < self.right  ? 1 : 2))
      iy = (y < self.y ? 0 : (y < self.bottom ? 1 : 2))
      return ix + iy * 3
    end

    def contain?(*a)
      case a.length
      when 1
        aleft, atop, aright, abottom = a.first.to_a
      when 2
        aleft, atop = *a
        aright, abottom = aleft, atop
      when 4
        aleft, atop, aright, abottom = *a
      else
        raise ArgumentError, "wrong number of arguments #{a.length} for 1, 2 or 4"
      end
      left <= aleft && top <= atop && right >= aright && bottom >= abottom
    end

    def union(*a)
      case a.length
      when 1
        oleft, otop, w, h = a.first.to_a
      when 4
        oleft, otop, w, h = *a
      else
        raise ArgumentError
      end
      oright = oleft + w
      obottom = otop + h
      nleft   = left   < oleft   ? left   : oleft
      ntop    = top    < otop    ? top    : otop
      nright  = right  > oright  ? right  : oright
      nbottom = bottom > obottom ? bottom : obottom
      self.x      = nleft
      self.y      = ntop
      self.width  = nright  - nleft
      self.height = nbottom - ntop
      self
    end

    def intersect(*a)
      case a.length
      when 1
        other = a.first
        oleft   = other.x
        otop    = other.y
        oright  = oleft + other.width
        obottom = otop  + other.height
      when 4
        oleft   = a[0]
        otop    = a[1]
        oright  = oleft + a[2]
        obottom = otop + a[3]
      else
        raise ArgumentError
      end
      right   = self.right
      bottom  = self.bottom
      nright  = right  < oright  ? right  : oright
      nbottom = bottom < obottom ? bottom : obottom
      self.x      = oleft if self.x < oleft
      self.y      = otop  if self.y < otop
      self.width  = nright  - x
      self.height = nbottom - y
      self
    end

    def inset_by(*a)
      case a.length
      when 1
        if a[0].respond_to? :left
          left = a[0].left
          top = a[0].top
          right = a[0].right
          bottom = a[0].bottom
        elsif Numeric === a[0]
          left = right = top = bottom = a[0]
        else
          raise TypeError, "wrong type of argument 0: should be Numeric or Rectangle"
        end
      when 2
        left = right = a[0]
        top = bottom = a[1]
      when 4
        left, top, right, bottom = a
      else
        raise ArgumentError, "wrong number of arguments #{a.length} for 2 or 4"
      end
      self.x += left
      self.width -= left + right
      self.y += top
      self.height -= top + bottom
      self
    end

    def offset_by(a1, a2 = nil)
      if a2 == nil
        self.x += a1.x
        self.y += a1.y
      else
        self.x += a1
        self.y += a2
      end
      self
    end

    def offset_to(a1, a2 = nil)
      if a2 == nil
        self.x = a1.x
        self.y = a1.y
      else
        self.x = a1
        self.y = a2
      end
      self
    end

    def resize_by(a1, a2 = nil)
      if a2
        self.width += a1
        self.height += a2
      else
        self.width += a1.width
        self.height += a1.height
      end
      self
    end

    def resize_to(a1, a2 = nil)
      if a2
        self.width = a1
        self.height = a2
      else
        self.width = a1.width
        self.height = a1.height
      end
      self
    end

    def int_all
      self.x      = self.x.to_i
      self.y      = self.y.to_i
      self.width  = self.width.to_i
      self.height = self.height.to_i
      self
    end

    def float_all
      self.x      = self.x.to_f
      self.y      = self.y.to_f
      self.width  = self.width.to_f
      self.height = self.height.to_f
      self
    end

    def &(other)
      self.dup.intersect other
    end

    def |(other)
      self.dup.union other
    end

    def size
      Size.new(width, height)
    end

    def to_a
      [x, y, width, height]
    end

    def box
      [x, y, x + width, y + height]
    end
  end

  class Rectangle < Struct.new(:x, :y, :width, :height)
    include RectangleMixin
  end
end
