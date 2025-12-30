require "wayland/cursor_support"

module Wayland
  module CursorSupport
    class XCursor
      XCURSOR_IMAGE_TYPE = 0xfffd0002
      XCURSOR_IMAGE_VERSION = 1
      XCURSOR_IMAGE_MAX_SIZE = 0x7fff

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
        im = CursorImage.new
        im.version = XCURSOR_IMAGE_VERSION
        im.width  = readu32le(io)
        im.height = readu32le(io)
        im.xhots  = readu32le(io)
        im.yhots  = readu32le(io)
        im.delay  = readu32le(io)
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
  end # CursorSupport
end # Wayland
