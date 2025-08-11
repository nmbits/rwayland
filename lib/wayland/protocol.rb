require 'yaml'
require 'wayland/wlobject'
require 'wayland/code_generator'

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

    def load(data)
      ns = Wayland
      @interfaces.merge! data
      data.each do |ifname, d|
        gen = CodeGenerator.new ifname, d
        code = gen.generate
        # print code
        eval code, Object::TOPLEVEL_BINDING
      end
    end
  end
end
