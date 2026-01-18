require "wayland/shared_memory"

module Wayland
  module Util
    class ImagePool
      DEFAULT_POOL_SIZE = 1024
      Entry = Struct.new(:offset, :width, :height, :stride, :format, :buffer)

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
        @images << Entry.new(offset, width, height, stride, format, nil)
        index
      end

      def get_buffer(index, as: nil)
        raise RangeError, "index out of range" if index < 0 || index >= @images.size
        e = @images[index]
        e.buffer ||= @pool.create_buffer e.offset, e.width, e.height, e.stride, e.format, as: as
      end
    end
  end
end
