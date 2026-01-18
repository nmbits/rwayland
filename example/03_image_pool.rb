require 'wayland'
require 'wayland/shared_memory'
require 'wayland/util/image_pool'
require 'cairo'
require 'logger'

module Example03

  SIZE = 128

  module_function

  def main
    display = Wayland::Wl::Display.connect
    display.set_logger Logger.new(STDOUT)
    display.get_registry
    display.roundtrip

    # surface
    compositor = display[:wl_compositor]
    wl_surface = compositor.create_surface

    # image pool
    ipool = Wayland::Util::ImagePool.new display[:wl_shm]

    image = Cairo::ImageSurface.new Cairo::FORMAT_ARGB32, SIZE, SIZE
    context = Cairo::Context.new image

    # circle
    context.set_source_rgb 1, 1, 1
    context.rectangle 0, 0, SIZE, SIZE
    context.fill

    context.line_width = 5
    context.set_source_rgb 0.5, 0.5, 0.5
    context.circle SIZE / 2, SIZE / 2, SIZE / 4
    context.stroke_preserve

    ipool.add_image SIZE, SIZE, SIZE * 4, Wayland::Wl::Shm[:format].xrgb8888, image.data

    # fill
    context.fill

    ipool.add_image SIZE, SIZE, SIZE * 4, Wayland::Wl::Shm[:format].xrgb8888, image.data

    xdg_surface = display[:xdg_wm_base].get_xdg_surface wl_surface
    xdg_surface.on :configure do |serial|
      xdg_surface.ack_configure serial
      buffer = ipool.get_buffer 0
      wl_surface.attach buffer, 0, 0
      wl_surface.commit
    end

    xdg_toplevel = xdg_surface.get_toplevel
    xdg_toplevel.set_title("Example Client")
    wl_surface.commit

    loop { display.dispatch }
  end
end

if __FILE__ == $0
  Example03.main
end
