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
      if F.ftruncate(fd, size) != 0
        F.close fd
        errno = Fiddle.last_error
        raise "ftruncate() failed. errno = #{errno}"
      end
      fd
    end
    private :new_shm

    def initialize(fd = nil, size: nil, mode: nil,
                   prot: PROT_RDWR, flags: MAP_SHARED)
      io = nil
      if size.nil? || size <= 0
        raise ArgumentError, "size must be greater than 0"
      end
      case fd
      when nil
        mode = 0600 unless mode
        fd = new_shm(size, mode)
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
      mmap prot, flags
    end

    def close
      if @tag.io
        io.close
        @tag.io = nil
      end
    end

    def mmap(prot, flags)
      raise "io already closed" unless io
      fd = io.to_i
      unless @tag.address
        ptr = MAP_FAILED
        20.times do
          ptr = F.mmap nil, size, prot, flags, fd, 0
          break unless ptr == MAP_FAILED
          errno = Fiddle.last_error
          next if errno == Errno::EAGAIN
          raise "mmap() failed. errno = #{errno}"
        end
        raise "mmap() failed" if ptr == MAP_FAILED
        @tag.address = ptr.to_i
      end
    end
    private :mmap

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
