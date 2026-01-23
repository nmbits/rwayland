require "wayland/free_list"
require 'wayland/util'

module Wayland
  class ObjectManager
    CLIENT_OBJECT_ID_MIN = 0x00000001
    CLIENT_OBJECT_ID_MAX = 0xFEFFFFFF
    def initialize
      @map = {}
      @free_list = FreeList.new(CLIENT_OBJECT_ID_MIN, CLIENT_OBJECT_ID_MAX)
    end

    def new_id
      value = @free_list.get
      raise RangeError unless value
      value
    end
    private :new_id

    def add_object(obj)
      @map[obj.wl_object_id] = obj
    end
    private :add_object

    def get_object(oid)
      @map[oid]
    end

    def get_objects_by_ifname(ifname)
      @map.each_value.find_all {|object| object.ifname == ifname }
    end

    def get_first_object_by_ifname(ifname)
      @map.each_value.find {|object| object.ifname == ifname }
    end

    def [](key)
      case key
      when Symbol
        get_first_object_by_ifname(key)
      when Integer
        get_object(oid)
      else
        raise TypeError
      end
    end

    def create_object(ifname, oid, mod)
      oid ||= new_id
      obj = new_object(ifname, oid, mod)
      add_object obj
      obj
    end

    def create_wl_display(socket, mod)
      oid = @free_list.get
      raise RuntimeError unless oid == 1
      obj = get_impl(:wl_display, mod).new(oid)
      @display = obj
      obj.set_socket socket
      obj.set_object_manager self
      add_object obj
      obj
    end

    def delete_id(oid)
      if obj = @map.delete(oid)
        @free_list.free oid
        @display.delete_log obj
      end
    end

    def get_default_impl(ifname)
      mname, cname = Util.ifname_to_cname ifname
      raise ArgumentError unless Wayland.const_defined? mname
      n = Wayland.const_get mname
      raise ArgumentError unless n.const_defined? cname
      n.const_get cname
    end

    def get_impl(ifname, mod)
      c = get_default_impl(ifname)
      mod = mod.first if Array === mod && !mod.empty?
      case mod
      when Class
        raise TypeError unless mod <= c
        c = mod
      when Module
        c = Class.new(c){ include mod }
      when nil
      # do nothing
      else
        raise ArgumentError
      end
      c
    end

    def new_object(ifname, oid, mod)
      obj = get_impl(ifname, mod).new(oid, @display)
      @display.create_log obj
      obj
    end
  end
end
