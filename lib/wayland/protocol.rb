require 'yaml'
require 'wayland/wlobject'

module Wayland
  module Protocol
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
          @display.send_request self, __callee__, rspec, *args, **hash
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
  end
end
