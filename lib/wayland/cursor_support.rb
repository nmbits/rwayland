module Wayland
  module CursorSupport
    class CursorImage < Struct.new(:version, :size, :width, :height, :xhots, :yhots, :delay, :pixels)
    end
  end
end

require "wayland/cursor_support/xcursor"
require "wayland/cursor_support/xcursor_theme"
