require "wayland/cursor_support"
require "wayland/cursor_support/xcursor"

module Wayland
  module CursorSupport
    class XCursorTheme
      XCURSORPATH = %w(~/.icons /usr/share/icons /usr/share/pixmaps ~/.cursors /usr/share/cursors/xorg-x11 /usr/X11R6/lib/X11/icons)
      XDG_DATA_HOME_FALLBACK = "~/.local/share"
      def initialize(name, size, xcursors)
        @name = name
        @size = size
        @xcursors = xcursors
      end
      attr_reader :name, :size

      def [](name)
        @xcursors[name]
      end

      def each(&blk)
        @xcursors.each_value &blk
      end

      def self.library_path
        env_var = ENV["XCURSOR_PATH"]
        return [env_var] if env_var

	env_var = ENV["XDG_DATA_HOME"]
        if env_var.nil? || !env_var.start_with?('/')
          env_var = XDG_DATA_HOME_FALLBACK
        end
        dir = File.join env_var, "icons"
        return [dir].concat XCURSORPATH
      end

      def self.theme_inherits(path)
        ans = nil
        File.open path do |io|
          io.each do |line|
            next unless /^Inherits\s*\=\s*(.*)/ =~ line
            ans = $1.split(/[\;\,]/).map{|i| i.strip }
            break
          end
        end
        ans
      end

      def self.load_all_cursors(pathes, theme, size, xcursors = {})
        inherits = nil
        pathes.each do |path|
          dir = File.expand_path theme, path
          wildcard = File.join dir, "cursors", "*"
          Dir.glob wildcard do |file|
            if File.readable? file
              begin
                xcursor = XCursor.load_path(file, size)
                xcursors[xcursor->name] ||= xcursor
              rescue => e
              end
            end
          end
          index_theme = File.join dir, "index.theme"
          if inherits.nil? && File.readable?(index_theme)
            inherits = theme_inherits index_theme
          end
        end
        if inherits
          inherits.each{|itheme| load_all_cursors pathes, itheme, size, xcursors }
        end
        xcursors
      end

      def self.load(theme, size)
        theme = "default" unless theme
        theme = theme.sub(/\:.*/, '')
        pathes = library_path
        if pathes.size > 0
          xcursors = load_all_cursors(pathes, theme, size)
        end
        if xcursors.size > 0
          return self.new(theme, size, xcursors)
        end
      end
    end # XCursorTheme
  end # CursorSupport
end # Wayland

if __FILE__ == $0
  theme = ARGV[0] || "default"
  Wayland::CursorSupport::XCursorTheme.load theme, 36
end
