require "wayland/wlobject"

module Wayland
  module Xdg
    class WmBase < WLObject
      def ping(serial)
        pong serial
      end
    end
  end
end
