require "wayland/util/image_pool"
require "wayland/cursor_support/cursor"
require "wayland/cursor_support/xcursor"

module Wayland
  module CursorSupport
    module_function
    def load_xcursor(wl_shm, theme, size)
      ibytes = size * size * 4
      ipool = Util::ImagePool.new wl_shm, ibytes
      theme = CursorTheme.new theme, size, ipool
      xt = XCursorTheme.load theme, size
      xt.each do |xc|
        xc.each do |xi|
          theme.add_cursor_image(xc.name, xi.width, xi.height, xi.xhots, xi.yhots, xi.delay, xi.pixels)
        end
      end
      theme
    end
  end
end
