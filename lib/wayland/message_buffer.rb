module Wayland
  class MessageBuffer
    def initialize
      setup
    end
    ZERO = "\0" * 256
    UNIT = 4

    def setup
      @buffer = ZERO.dup
      @rd = 0
      @wr = 0
    end

    def empty?
      @rd == @wr
    end

    def bytesize
      b = @wr - @rd
      b >= 0 ? b : b + @buffer.bytesize
    end

    def write(string)
      idx = 0
      rem = string.bytesize
      while rem > 0
        cp_last = (@rd <= @wr ? @buffer.bytesize : @rd - UNIT)
        cp_last -= UNIT if @rd == 0
        cp_cap = cp_last - @wr
        if cp_cap <= 0
          @buffer.bytesplice @wr, 0, ZERO
          @rd += ZERO.bytesize if @rd > cp_last
          next
        end
        cp_sz = rem < cp_cap ? rem : cp_cap
        @buffer.bytesplice @wr, cp_sz, string, idx, cp_sz
        idx += cp_sz
        rem -= cp_sz
        @wr += cp_sz
        @wr = 0 if @wr >= @buffer.bytesize
      end
    end

    def read(bytes)
      retval = String.new
      raise RangeError if bytes > self.bytesize
      rem = bytes
      while rem > 0
        cp_last = (@rd <= @wr ? @wr : @buffer.bytesize)
        cp_cap = cp_last - @rd
        cp_sz = rem < cp_cap ? rem : cp_cap
        retval << @buffer.byteslice(@rd, cp_sz)
        rem -= cp_sz
        @rd += cp_sz
        @rd = 0 if @rd >= @buffer.bytesize
      end
      retval
    end

    def read_object
      read_uint
    end

    def read_uint
      read(4).unpack1 "L"
    end

    def read_int
      read(4).unpack1 "l"
    end

    def read_fixed
      read_int.to_f / (2**8)
    end

    def read_blob(zterm)
      bytes = read_uint
      return nil if bytes == 0
      read_bytes = ((bytes + 3) / 4) * 4
      ans = read read_bytes
      len = bytes - (zterm ? 1 : 0)
      pad = read_bytes - len
      ans.bytesplice(len, pad, "")
      ans
    end
    private :read_blob

    def read_string
      read_blob true
    end

    def read_array
      read_blob false
    end

    def clear
      setup
    end
  end
end

if __FILE__ == $0

  buf = Wayland::MessageBuffer.new

  buf.write "0123"
  buf.write "4567"
  p buf.read(4)
  p buf
  buf.write "89ab"
  p buf.read(4)
  p buf.read(4)

  p buf
end
