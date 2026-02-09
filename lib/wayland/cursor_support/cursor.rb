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

      def create_buffer(as: nil)
        @cursor.theme.image_pool.create_buffer(@index, as: as)
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

      SHAPES = %w[default    context_menu help        pointer     progress
                  wait       cell         crosshair   text        vertical_text
                  alias      copy         move        no_drop     not_allowed
                  grab       grabbing     e_resize    n_resize    ne_resize
                  nw_resize  s_resize     se_resize   sw_resize   w_resize
                  ew_resize  ns_resize    nesw_resize nwse_resize col_resize
                  row_resize all_scroll   zoom_in     zoom_out    dnd_ask
                  all_resize]

      def shape_to_name(shape)
        if shape > 0 && shape <= SHAPES.size
          SHAPES[shape - 1]
        end
      end
      private :shape_to_name

      def [](name)
        case name
        when Integer
          sname = shape_to_name name
          raise ArgumentError unless sname
        when String
          sname = name.include?("-") ? name.gsub(/\-/, "_") : name
        else
          raise TypeError
        end
        return @cursors[sname]
      end

      def names
        @cursors.keys
      end

      def add_cursor_image(name, width, height, hotspot_x, hotspot_y, delay, pixels)
        nml_name = name.gsub /\-/, "_"
        cursor = (@cursors[nml_name] ||= Cursor.new(self, nml_name))
        index = @image_pool.add_image width, height, width * 4,
                                      Wayland::Wl::Shm[:format].argb8888, pixels
        image = CursorImage.new cursor, index, hotspot_x, hotspot_y, delay
        cursor.add_image image
      end
    end
  end
end
