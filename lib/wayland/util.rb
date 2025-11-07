module Wayland
  module Util
    ZERO4 = "\0" * 4

    module_function

    def ifname_to_cname(ifname)
      a = ifname.to_s.split("_").map{|i| i.capitalize }
      mod = a.shift
      c = a.join
      return mod, c
    end

    # append zero to +str+ to be 4B aligned
    #
    # +str+   :: string
    # +zterm+ :: returns zero terminated string
    # +return+ :: string, str_size
    #
    def pad_string(str, zterm)
      str = str.dup
      len = str.bytesize
      pad = 4 - (len % 4)
      zterm = zterm && (str.getbyte(-1) != 0)
      if pad != 4 || zterm
        str = str.bytesplice(len, pad, ZERO4, 0, pad)
      end
      return str, len + (zterm ? 1 : 0)
    end
  end
end
