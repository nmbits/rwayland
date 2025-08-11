require 'wayland/wlobject'
require 'wayland/protocol'

module Wayland
  module Wl
    class Registry < WLObject
      def global(name, interface, version)
        sym = interface.to_sym
        intf = Protocol[sym]
        if intf
          bind name, interface, [version, intf[:version]].min, sym
        end
      end
    end
  end
end
