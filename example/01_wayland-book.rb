require 'wayland'
require 'wayland/shared_memory'
require 'wayland/xkb_support'
require 'logger'

module WaylandBook

  module CBMixin
    def post_init(state)
      @state = state
    end

    def done(time)
      cb = @state.wl_surface.frame as: [CBMixin, @state]
      if @state.last_frame != 0
        elapsed = time - @state.last_frame
        @state.offset += elapsed / 1000.0 * 24
      end
      buffer = WaylandBook.draw_frame @state
      @state.wl_surface.attach buffer, 0, 0
      @state.wl_surface.damage_buffer 0, 0, 0x7fffffff, 0x7fffffff
      @state.wl_surface.commit
      @state.last_frame = time
    end
  end
    
  module_function

  def draw_frame(state)
    display = state.wl_display

    width = 640
    height = 480
    stride = width * 4
    size = stride * height

    shared_memory = Wayland::SharedMemory.new size: size

    pool = display[:wl_shm].create_pool(shared_memory.fd, size)
    buffer = pool.create_buffer(0, width, height, stride, Wayland::Wl::Shm[:format].xrgb8888)
    pool.destroy

    offset = state.offset.to_i % 8

    ff6666ee = [0xff6666ee].pack("L")
    ffeeeeee = [0xffeeeeee].pack("L")

    height.times do |y|
      width.times do |x|
        if (((x + offset) + (y + offset) / 8 * 8) % 16 < 8)
          shared_memory.write(y * stride + x * 4, ff6666ee, 4)
        else
          shared_memory.write(y * stride + x * 4, ffeeeeee, 4)
        end
      end
    end
    buffer.on(:release) { buffer.destroy }
    buffer
  end

  def main
    display = Wayland::Wl::Display.connect
    display.set_logger Logger.new(STDOUT)
    display.get_registry
    display.roundtrip

    compositor = display[:wl_compositor]
    wl_surface = compositor.create_surface

    state = Struct.new(:wl_display, :wl_surface, :offset, :last_frame).new(display, wl_surface, 0, 0)

    xdg_surface = display[:xdg_wm_base].get_xdg_surface wl_surface
    xdg_surface.on :configure do |serial|
      xdg_surface.ack_configure serial
      buffer = draw_frame(state)
      wl_surface.attach buffer, 0, 0
      wl_surface.commit
    end

    xdg_toplevel = xdg_surface.get_toplevel
    xdg_toplevel.set_title("Example Client")
    wl_surface.commit

    cb = wl_surface.frame as: [CBMixin, state]

    loop { display.dispatch }
  end
end

if __FILE__ == $0
  WaylandBook.main
end
