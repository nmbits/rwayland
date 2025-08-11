require 'wayland/protocol'

module Wayland
  class WLObject
    INT_RANGE           = (-2147483648..2147483647)
    UINT_RANGE          = (0..4294967295)
    CLIENT_OBJECT_RANGE = (1..0xFEFFFFFF)
    FIXED_RANGE         = ((-0x80000000.to_f / 2**8)..(0x7fffffff.to_f / 2**8))

    attr_reader :wl_object_id
    undef :initialize_copy

    def initialize(wl_object_id, wl_display)
      @wl_object_id = wl_object_id
      @display = wl_display
    end

    def post_init
    end

    def on(event, delegate: nil, name: nil, &br)
      unless Protocol[ifname][:events].find{|e| e[:name] == event}
        raise ArgumentError, "#{ifname} has no event \"#{event}\""
      end
      if delegate
        raise ArgumentError, "block cannot be specified w/ delegate" if br
        raise "object has no method named \"#{name}\"" unless delegate.respond_to? name
      else
        raise ArgumentError, "name cannot be specified w/o delegate" if name
        raise "no block given" unless br
        delegate = br
        name = :call
      end
      define_singleton_method event do |*a| delegate.__send__ name, *a end
      self
    end

    def pad_array(s)
      len = s.bytesize
      pad = (4 - (len & 3)) & 3
      s << "\0" * pad
      s
    end

    def pad_string(str)
      s = str.getbyte(-1) > 0 ? str + "\0" : str
      pad_array(s)
    end

    def check_int(value)
      value.is_a?(Integer) && INT_RANGE.include?(value)
    end

    def check_uint(value)
      value.is_a?(Integer) && UINT_RANGE.include?(value)
    end

    def check_fixed(value)
      value.is_a?(Float) && FIXED_RANGE.include?(value)
    end

    def deleted
      @display.delete_log self
    end
  end
end
