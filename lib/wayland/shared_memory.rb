require 'fiddle/import'

module Wayland
  class SharedMemory
    PROT_READ   = 0x1
    PROT_WRITE  = 0x2
    PROT_RDWR   = PROT_READ | PROT_WRITE
    MAP_SHARED  = 0x1
    MAP_PRIVATE = 0x2
    MAP_FAILED  = Fiddle::Pointer.new(-1)
    LONG_SIZE   = [-1].pack("l!").bytesize * 8
    INT_SIZE    = [-1].pack("i!").bytesize * 8
    PTR_SIZE    = [-1].pack("j!").bytesize * 8
    module F
      extend Fiddle::Importer
      dlload "librt.so.1", "libc.so.6"
      extern "int shm_open(void *, int, int)"
      extern "int shm_unlink(void *)"
      extern "int ftruncate(int, long)"
      extern "int close(int)"
      extern "void *mmap(void *, size_t, int, int, int, long)"
      extern "int munmap(void *, size_t)"
    end

    undef_method :initialize_dup, :initialize_clone, :initialize_copy

    class Tag < Struct.new(:io, :size, :address)
      def destroy
        F.munmap address, size if address
        io.close if io
        self.io      = nil
        self.size    = nil
        self.address = nil
      end
    end
    @@tags = {}

    def self.finalizer
      proc {|oid| @@tags.delete(oid)&.destroy }
    end

    def new_shm(size, mode)
      fd = -1
      oflags = File::Constants::RDWR | File::Constants::CREAT | File::Constants::EXCL
      20.times do
        r = rand(0x100000000)
        name = "/wayland-ruby-shm-#{$$}-#{'%08x' % r}"
        fd = F.shm_open(name, oflags, mode)
        if fd >= 0
          F.shm_unlink(name)
          break
        end
      end
      if fd < 0
        errno = Fiddle.last_error
        raise "shm_open() failed. errno = #{errno}"
      end
      truncate fd, size
      fd
    end
    private :new_shm

    def truncate(fd, size)
      if F.ftruncate(fd, size) != 0
        errno = Fiddle.last_error
        raise "ftruncate() failed. errno = #{errno}"
      end
    end
    private :truncate

    def initialize(fd = nil, size: nil, mode: nil,
                   prot: PROT_RDWR, flags: MAP_SHARED)
      @allocated = 0
      @prot = prot
      @flags = flags
      io = nil
      if size.nil? || size <= 0
        raise ArgumentError, "size must be greater than 0"
      end
      case fd
      when nil
        mode = 0600 unless mode
        fd = new_shm size, mode
        io = IO.for_fd fd
      when Integer
        raise ArgumentError, "fd must be greater than 0" if fd < 0
        io = IO.for_fd fd
      when IO
        io = fd
      else
        raise TypeError, "the first argument should be nil, an instance of Integer or IO"
      end
      @tag = Tag.new io, size, nil
      @@tags[self.object_id] = @tag
      ObjectSpace.define_finalizer self, SharedMemory.finalizer
      mmap
    end

    def allocate(size, resize: false)
      if size + @allocated > @tag.size
        return nil unless resize
        self.resize size + @allocated
      end
      offset = @allocated
      @allocated += size
      offset
    end

    def close
      if @tag.io
        io.close
        @tag.io = nil
      end
    end
    private :close

    def mmap
      unless @tag.address
        raise FrozenError, "can't change frozen memory mapping" if frozen?
        raise "io already closed" unless @tag.io
        fd = @tag.io.to_i
        ptr = MAP_FAILED
        20.times do
          ptr = F.mmap nil, @tag.size, @prot, @flags, fd, 0
          break unless ptr == MAP_FAILED
          errno = Fiddle.last_error
          next if errno == Errno::EAGAIN
          raise "mmap() failed. errno = #{errno}"
        end
        raise "mmap() failed" if ptr == MAP_FAILED
        @tag.address = ptr.to_i
        @pointer = ptr
      end
    end
    private :mmap

    def munmap()
      if @tag.address
        raise FrozenError, "can't change frozen memory mapping" if frozen?
        F.munmap @tag.address, @tag.size
        @tag.address = nil
        @pointer = nil
      end
    end
    private :munmap

    def resize(newsize)
      raise RangeError, "new size must be greater than current size" if newsize < size
      return nil if newsize == size
      raise "io already closed" unless @tag.io
      raise FrozenError, "can't change frozen memory mapping" if frozen?
      munmap
      truncate @tag.io.to_i, newsize
      @tag.size = newsize
      mmap
      nil
    end

    def read(offset, bytes)
      if offset < 0 || offset >= @tag.size
        raise RangeError, "offset exceeds size"
      end
      if bytes <= 0
        raise ArgumentError, "bytes should be greather than 0"
      end
      if offset + bytes > @tag.size
        bytes = offset + bytes - @tag.size
      end
      @pointer[offset, bytes]
    end

    def write(offset, str, bytes = nil, resize: false)
      bytes = str.bytesize if bytes.nil?
      if offset < 0 || offset >= @tag.size
        raise RangeError, "offset exceeds size"
      end
      if bytes <= 0
        raise ArgumentError, "bytes should be greather than 0"
      end
      if offset + bytes > @tag.size
        raise RangeError, "string exceeds size" unless resize
        newsize = offset + bytes
        self.resize newsize
      end
      @pointer[offset, bytes] = str
    end

    def freeze
      unless frozen?
        close
        super
      end
    end

    def address
      @tag.address
    end

    def size
      @tag.size
    end

    def io
      @tag.io
    end

    def fd
      @tag.io&.to_i
    end
  end
end
