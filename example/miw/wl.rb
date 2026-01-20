require 'wayland'
require 'miw/wl/private'

module MiW
  module Wl
    def self.init
      @display = Wayland::Wl::Display.connect
      registry = @display.get_registry
      registry.set_global_module(wl_seat: Private::WlSeat)
      @display.roundtrip
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
