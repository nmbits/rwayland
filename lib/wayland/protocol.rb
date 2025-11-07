require 'yaml'
require 'wayland/wlobject'
require 'wayland/util'

module Wayland
  module Protocol
    INT_RANGE           = (-2147483648..2147483647)
    UINT_RANGE          = (0..4294967295)
    CLIENT_OBJECT_RANGE = (1..0xFEFFFFFF)
    FIXED_RANGE         = ((-0x80000000.to_f / 2**8)..(0x7fffffff.to_f / 2**8))

    @interfaces = {}

    TYPE_TEMPLATE_CHAR = {
      int: 'l', uint: 'L', fixed: 'l', object: 'L', new_id: 'L', string: 'La*', array: 'La*', fd: ''
    }
    
    module_function

    def [](ifname)
      @interfaces[ifname]
    end

    def load_yaml(yaml)
      self.load YAML.load_file(yaml)
    end

    def get_module(mname)
      if Wayland.const_defined? mname
        Wayland.const_get mname
      else
        Wayland.const_set mname, Module.new
      end
    end

    def setup_request_methods(clazz, requests)
      requests.each do |name, rspec|
        arg_types = rspec[:args].map{|a| a[:type] }
        rspec[:pack_template] = "LL" + TYPE_TEMPLATE_CHAR.values_at(*arg_types).join
        rspec[:base_size] = arg_types.inject(8 << 16) do |r, type|
          r + case type
              when :string, :array, :fd
                0
              else
                4 << 16
              end
        end
        clazz.define_method name do |*args, **hash|
          rspec = Wayland::Protocol[ifname][:requests][__callee__]
          Protocol.send_request @display, self, __callee__, rspec, *args, **hash
        end
      end
    end

    def setup_enums(clazz, enums)
      hash = Hash.new
      enums.each do |enum|
        ename = enum[:name]
        names = enum[:entries].map{|ent| ent[:name] }
        values = enum[:entries].map{|ent| ent[:value] }
        hash[ename] = Struct.new(*names).new(*values).freeze
      end
      hash.freeze
      clazz.const_set :WL_ENUMS, hash
      clazz.define_singleton_method(:[]){|n| self.const_get(:WL_ENUMS)[n] }
    end

    def define_class(ifname)
      mname, cname = Util.ifname_to_cname ifname
      mod = get_module(mname)
      clazz = Class.new(Wayland::WLObject)
      mod.const_set cname, clazz
      clazz.const_set :IFNAME, ifname.freeze
      clazz.define_method(:ifname){ self.class.const_get(:IFNAME) }
      clazz
    end

    def load(data)
      @interfaces.merge! data
      data.each do |ifname, ispec|
        clazz = define_class(ifname)
        setup_request_methods clazz, ispec[:requests]
        setup_enums clazz, ispec[:enums]
      end
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

    def send_request(display, wlobj, sym, rspec, *margs, as: nil)
      pack_template = rspec[:pack_template]
      size = rspec[:base_size]
      opcode = rspec[:opcode]
      alist = [wlobj.wl_object_id, 0]
      obj = nil
      ancdata = nil
      i = 0
      rspec[:args].each do |arg|
        case arg[:type]
        when :string, :array
          str, str_size = Util.pad_string margs[i], arg[:type] == :string
          size += (str.bytesize + 4) << 16
          alist << str_size
          alist << str
          i += 1
        when :new_id
          interface = arg[:interface]
          if interface
            obj = display.create_object interface, nil, as
          else
            obj = display.create_object margs[i], nil, as
            i += 1
          end
          alist << obj.wl_object_id
        when :fd
          ancdata = Socket::AncillaryData.int(:UNIX, :SOCKET, :RIGHTS, margs[i])
          i += 1
        when :object
          alist << margs[i].wl_object_id
          i += 1
        when :fixed
          alist << (margs[i] * (2 ** 8)).to_i
          i += 1
        else
          alist << margs[i]
          i += 1
        end
      end
      alist[1] = opcode | size
      message = alist.pack pack_template
      display.request_log wlobj, sym, pack_template, *alist, message
      if ancdata
        display.socket.sendmsg message, 0, nil, ancdata
      else
        display.socket.sendmsg message, 0, nil
      end
      return obj
    end

    def dispatch(display, buffer, ios)
      count = 0
      loop do
        break if buffer.bytesize < 8
        oid, opsz = buffer.peek(8).unpack "LL"
        if oid == 0
          buffer.discard 8
          next
        end
        opcode = opsz & 0xffff
        size = (opsz >> 16)
        break if buffer.bytesize < size
        buffer.discard 8
        dispatch_event display, oid, opcode, buffer, size - 8, ios
        count += 1
      end
      count
    end

    GUARD = WLObject.new nil, nil

    def dispatch_event(display, oid, opcode, buffer, size, ios)
      object = display.get_object oid
      raise "object 0x#{oid.to_s(16)} not found" unless object
      intf = Protocol[object.ifname]
      evs = intf[:events]
      ev = evs ? evs[opcode] : nil
      unless ev
        pp [opcode, object.ifname, evs]
        raise RuntimeError
      end
      name = ev[:name]
      args = ev[:args].map do |a|
        case a[:type]
        when :int
          buffer.read_int
        when :uint
          buffer.read_uint
        when :object
          display.get_object buffer.read_object
        when :fixed
          buffer.read_fixed
        when :new_id
          display.create_object a[:interface], buffer.read_object
        when :string
          buffer.read_string
        when :array
          buffer.read_array
        when :fd
          ios.shift || raise("no io for fd arg")
        end
      end
      f = object.respond_to?(name)
      if f && GUARD.respond_to?(name)
        raise "event #{name} rejected"
      end
      display.event_log f, oid, object.ifname, name, *args
      object.__send__ name, *args if f
    end
  end
end
