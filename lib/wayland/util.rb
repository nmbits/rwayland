module Wayland
  class Util
    def self.ifname_to_cname(ifname)
      a = ifname.to_s.split("_").map{|i| i.capitalize }
      mod = a.shift
      c = a.join
      return mod, c
    end
  end
end
