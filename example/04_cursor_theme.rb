$: << File.dirname(__FILE__)
require "miw/wl"
require "miw/wl/toplevel"
require "wayland/cursor_support"

class ToplevelWindow
  def initialize(width, height, cursor_theme)
    @window = MiW::Wl::Toplevel.new(self, width, height)
    @cursor_theme = cursor_theme
  end

  def draw(context, rect)
    size = @window.client_size
    width = size.width
    height = size.height
    context.set_source_color [0.8, 0.8, 0.8, 1.0]
    context.rectangle 0, 0, width, height
    context.fill

    # cursors
    x = y = 0
    max_height = 0
    @cursor_theme.names.each do |name|
      cursor = @cursor_theme[name]
      cursor.count.times do |index|
        cursor_image = cursor[index]
        data = cursor_image.pixels
        stride = cursor_image.width * 4
        max_height = [max_height, cursor_image.height].max
        # p [cursor_image.width, cursor_image.height, data.bytesize, stride * cursor_image.height]
        image_surface = Cairo::ImageSurface.new data,
                                                Cairo::Format::ARGB32,
                                                cursor_image.width,
                                                cursor_image.height,
                                                stride
        context.set_source image_surface, x, y
        context.rectangle x, y, cursor_image.width, cursor_image.height
        context.fill
        x += cursor_image.width
        if x + cursor_image.width > @window.client_size.width
          y += max_height
          x = 0
          max_height = 0
        end
      end
    end
  end

  def hit_test(x, y)
    :client
  end

  def resized
  end

  def activated(active)
  end

  def pointer_enter(*_)
  end

  def pointer_leave(*_)
  end

  def pointer_motion(time, x, y)
  end

  def pointer_button(time, button, state)
  end

  def pointer_axis(time, axis, value)
  end

  def pulse
  end

  def keyboard_key(time, key, state)
  end

  def invalidate
    size = @window.client_size
    @window.invalidate_client 0, 0, size.width, size.height
  end
end

if __FILE__ == $0
  MiW::Wl.init(cursor_theme: "default", cursor_size: 24)
  display = MiW::Wl.display_instance
  wl_shm = display[:wl_shm]
  cursor_theme = MiW::Wl.cursor_theme
  toplevel_window = ToplevelWindow.new 640, 480, cursor_theme
  MiW::Wl.main_loop
end
