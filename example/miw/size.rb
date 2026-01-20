
module MiW
  module SizeMixin
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
  end

  class Size < Struct.new(:width, :height)
    include SizeMixin
  end
end
