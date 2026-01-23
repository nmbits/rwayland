require 'wayland'
require 'wayland/cursor_support'
require 'miw/wl/private'
require 'logger'

module MiW
  module Wl
    def self.init(**config)
      Wayland::Protocol.load_yaml File.join(File.dirname(__FILE__), "xdg-decoration-unstable-v1.yaml")
      @display = Wayland::Wl::Display.connect
      # @display.set_logger Logger.new(STDOUT)
      registry = @display.get_registry
      registry.set_global_module(wl_seat: Private::WlSeat)
      @display.roundtrip
      load_cursor_theme config[:cusor_theme], config[:cursor_size]
    end

    def self.load_cursor_theme(theme, size)
      wl_shm = @display[:wl_shm]
      @cursor_surfaces = Hash.new
      @cursor_theme = Wayland::CursorSupport.load_xcursor wl_shm, theme, size
      %w(nw-resize n-resize ne-resize  w-resize arrow e-resize sw-resize s-resize se-resize).each do |name|
        surface = @display[:wl_compositor].create_surface
        image = cursor_theme[name][0]
        wl_buffer = image.wl_buffer
        surface.attach wl_buffer, 0, 0
        surface.commit
        @cursor_surfaces[name] = [surface, image.hotspot_x, image.hotspot_y]
      end
    end

    def self.cursor_surface(name)
      @cursor_surfaces[name]
    end

    def self.cursor_theme
      @cursor_theme
    end

    def self.main_loop
      tm0 = Time.now
      loop do
        @display.dispatch 0.02
        tm1 = Time.now
        if tm1 - tm0 > 0.02
          @display.get_objects_by_ifname(:wl_surface).each do |s|
            if s.respond_to? :window
              s.window&.pulse
            end
          end
          tm0 = tm1
        end
      end
    end

    def self.display_instance
      @display
    end
  end
end
