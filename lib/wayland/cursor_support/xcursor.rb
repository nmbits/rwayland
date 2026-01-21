module Wayland
  module CursorSupport
    class XCursor
      XCURSOR_IMAGE_TYPE = 0xfffd0002
      XCURSOR_IMAGE_VERSION = 1
      XCURSOR_IMAGE_MAX_SIZE = 0x7fff

      class Image < Struct.new(:version, :width, :height, :xhots, :yhots, :delay, :size, :pixels)
      end

      class FileHeader < Struct.new(:magic, :header, :version, :ntoc, :tocs)
        def each_toc(&blk)
          if block_given?
            self.tocs.each &blk
          else
            self.tocs.each
          end
        end

        def each_image_toc
          if block_given?
            each_toc{|toc| yield toc if toc.image? }
          else
            self.to_enum __callee__
          end
        end

        def best_size(size)
          each_image_toc.inject 0 do |r, toc|
            toc_size = toc.subtype
            toc.image? && (toc_size - size).abs < (toc_size - r).abs ? toc_size : r
          end
        end
      end

      class Toc < Struct.new(:type, :subtype, :position)
        def seek(io)
          io.seek position, :SET
        end

        def image?
          self.type == XCURSOR_IMAGE_TYPE
        end
      end

      class ChunkHeader < Struct.new(:header, :type, :subtype, :version)
        def image?
          self.type == XCURSOR_IMAGE_TYPE
        end
      end

      def initialize(name, version, size, cursor_images)
        @name = name
        @version = version
        @size = size
        @cursor_images = cursor_images
      end
      attr_reader :name, :version, :size

      def cursor_image(i)
        @cursor_images[i]
      end

      def each(&blk)
        @cursor_images.each &blk
      end

      def count_image
        @cursor_images.size
      end

      def self.load_path(path, size)
        cursor_images = []
        version = nil
        best_size = 0
        File.open(path) do |io|
          file_header = read_file_header(io)
          version = file_header.version
          best_size = file_header.best_size size
          file_header.each_image_toc do |toc|
            cursor_images << read_image(io, toc).freeze if toc.subtype == best_size
          end
        end
        self.new File.basename(path), version, best_size, cursor_images
      end

      def self.readu32le(io)
        s = io.read(4)
        raise "Cannot read 4B" if s.nil? || s.bytesize != 4
        s.unpack1 "L<"
      end

      def self.read_file_header(io)
        io.seek 0, :SET
        header = FileHeader.new
        header.magic   = io.read(4)
        raise "Not a xcursor file" unless header.magic == "Xcur"
        header.header  = readu32le(io)
        header.version = readu32le(io)
        header.ntoc    = readu32le(io)
        header.tocs    = []
        io.seek header.header, :SET
        header.ntoc.times do |i|
          toc = Toc.new
          toc.type     = readu32le(io)
          toc.subtype  = readu32le(io)
          toc.position = readu32le(io)
          header.tocs << toc
        end
        header
      end

      def self.read_chunk_header(io, toc)
        ch = ChunkHeader.new
        io.seek toc.position, IO::SEEK_SET
        ch.header  = readu32le(io)
        ch.type    = readu32le(io)
        ch.subtype = readu32le(io)
        ch.version = readu32le(io)
        if ch.type != toc.type || ch.subtype != toc.subtype
          raise "type or subtype mismatch"
        end
        ch
      end

      def self.read_image(io, toc)
        ch = read_chunk_header(io, toc)
        im = Image.new XCURSOR_IMAGE_VERSION, # version
                       readu32le(io),         # width
                       readu32le(io),         # height
                       readu32le(io),         # xhots
                       readu32le(io),         # yhots
                       readu32le(io)          # delay
        if im.width > XCURSOR_IMAGE_MAX_SIZE || im.height > XCURSOR_IMAGE_MAX_SIZE ||
           im.width == 0 || im.height == 0 || im.xhots > im.width || im.yhots > im.height
          raise "Invalid file"
        end
        if ch.version < im.version
          im.version = ch.version
        end
        im.size = ch.subtype
        im.pixels = io.read im.width * im.height * 4
        im
      end
    end # XCursor

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
                xcursors[xcursor.name] ||= xcursor
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
