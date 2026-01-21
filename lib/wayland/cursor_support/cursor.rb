module Wayland
  module CursorSupport
    class CursorImage
      def initialize(cursor, index, hotspot_x, hotspot_y, delay)
        @cursor = cursor
        @index = index
        @hotspot_x = hotspot_x
        @hotspot_y = hotspot_y
        @delay = delay
      end
      attr_reader :cursor, :hotspot_x, :hotspot_y, :delay

      def wl_buffer(as: nil)
        @cursor.theme.image_pool.get_buffer(@index, as: as)
      end

      def width
        @cursor.theme.image_pool.attribute(@index).width
      end

      def height
        @cursor.theme.image_pool.attribute(@index).height
      end

      def format
        @cursor.theme.image_pool.attribute(@index).format
      end

      def pixels
        @cursor.theme.image_pool.pixels(@index)
      end
    end

    class Cursor
      def initialize(theme, name)
        @theme = theme
        @name = name
        @images = []
      end
      attr_reader :name, :size
      attr_accessor :theme

      def count
        @images.size
      end

      def [](index)
        @images[index]
      end

      def add_image(image)
        @images << image
      end
    end

    class CursorTheme
      def initialize(name, image_pool)
        @name = name
        @image_pool = image_pool
        @cursors = {}
      end
      attr_reader :name, :image_pool

      def [](name)
        @cursors[name]
      end

      def names
        @cursors.keys
      end

      def add_cursor_image(name, width, height, hotspot_x, hotspot_y, delay, pixels)
        cursor = (@cursors[name] ||= Cursor.new(self, name))
        index = @image_pool.add_image width, height, width * 4,
                                      Wayland::Wl::Shm[:format].argb8888, pixels
        image = CursorImage.new cursor, index, hotspot_x, hotspot_y, delay
        cursor.add_image image
      end
    end
  end
end
