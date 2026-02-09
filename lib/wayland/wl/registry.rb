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
          vr = [version, intf[:version]].min
          bind name, interface, vr, sym, as: mod
          (@interface_versions ||= Hash.new)[sym] = vr
        end
      end

      def interface_version(interface)
        @interface_versions && @interface_versions[interface.to_sym]
      end
    end
  end
end
