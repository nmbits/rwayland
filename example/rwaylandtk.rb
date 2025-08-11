require 'wayland'
require 'rwaylandtk/custom_wl_interface'
require 'rwaylandtk/toplevel_window'

module RWaylandTk
  def self.init
    @@display = Wayland::Wl::Display.connect
    @@display.get_registry as: CustomWaylandInterface::WlRegistry
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
