require 'wayland/wlobject'
require 'wayland/protocol'

module Wayland
  module Wl
    class Registry < WLObject
      def set_global_module(hash)
        @global_modules ||= Hash.new
        @global_modules.merge! hash
      end

      def global(name, interface, version)
        sym = interface.to_sym
        intf = Protocol[sym]
        if intf
          mod = @global_modules ? @global_modules[sym] : nil
          bind name, interface, [version, intf[:version]].min, sym, as: mod
        end
      end
    end
  end
end
