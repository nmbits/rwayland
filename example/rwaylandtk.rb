require 'wayland'
require 'rwaylandtk/custom_wl_interface'
require 'rwaylandtk/toplevel_window'
require 'logger'

module RWaylandTk
  def self.init
    @@display = Wayland::Wl::Display.connect
    @@display.set_logger Logger.new(STDOUT)
    registry = @@display.get_registry
    registry.set_global_module :wl_seat => CustomWaylandInterface::WlSeat
    @@display.roundtrip
    nil
  end

  def self.display_instance
    @@display
  end

  def self.set_logger(logger)
    @@display.set_logger logger
  end

  def self.main_loop
    loop{ @@display.dispatch }
  end
end
