require 'wayland/protocol'
require 'wayland/wlobject'
require 'wayland/util'

module Wayland
  def self.require_wayland_core(yaml)
    Protocol.load_yaml yaml
    require "wayland/wl/display"
    require "wayland/wl/registry"
  end

  def self.require_xdg_shell(yaml)
    Protocol.load_yaml yaml
    require 'wayland/xdg/wm_base'
  end

  dir = File.join(File.dirname(__FILE__), "wayland")
  core_yaml =
    const_defined?(:CORE_YAML) ?
      CORE_YAML : File.join(dir, "wayland.yaml")
  xdg_shell_yaml =
    const_defined?(:XDG_BASE_YAML) ?
      XDG_BASE_YAML : File.join(dir, "xdg-shell.yaml")
  require_wayland_core core_yaml
  require_xdg_shell xdg_shell_yaml
end
