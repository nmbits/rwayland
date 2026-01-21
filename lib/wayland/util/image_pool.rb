require "wayland/shared_memory"

module Wayland
  module Util
    class ImagePool
      DEFAULT_POOL_SIZE = 4096
      Entry = Struct.new(:offset, :attr, :buffer)
      Attribute = Struct.new(:width, :height, :stride, :format)

      def initialize(wl_shm, size = nil)
        @size = size || DEFAULT_POOL_SIZE
        @shm = SharedMemory.new size: @size
        @pool = wl_shm.create_pool @shm.fd, @size
        @pool.instance_variable_set :@__shared_meory, @shm
        @images = []
      end

      def add_image(width, height, stride, format, pixels)
        raise ArgumentError, "invalid size" if width <= 0 || height <= 0
        asize = height * stride
        offset = @shm.allocate asize, resize: true
        if @size < @shm.size
          @size = @shm.size
          @pool.resize @size
        end
        @shm.write offset, pixels, asize
        index = @images.size
        attr = Attribute.new(width, height, stride, format).freeze
        @images << Entry.new(offset, attr, nil)
        index
      end

      def get_buffer(index, as: nil)
        raise RangeError, "index out of range" if index < 0 || index >= @images.size
        e = @images[index]
        unless e.buffer
          a = e.attr
          e.buffer = @pool.create_buffer e.offset, a.width, a.height, a.stride, a.format, as: as
        end
        e.buffer
      end

      def attribute(index)
        raise RangeError, "index out of range" if index < 0 || index >= @images.size
        @images[index].attr
      end

      def pixels(index)
        raise RangeError, "index out of range" if index < 0 || index >= @images.size
        e = @images[index]
        a = attribute(index)
        @shm.read(e.offset, a.height * a.stride)
      end
    end
  end
end
