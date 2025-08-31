require 'erb'
require 'wayland/util'
require 'wayland/wlobject'

module Wayland
  class CodeGenerator
    TYPE_TEMPLATE_CHAR = {
      int: 'l', uint: 'L', fixed: 'l', object: 'L', new_id: 'L', string: 'La*', array: 'La*', fd: ''
    }
    TEMPLATE_FILE_NAME = "code_template.erb"

    def initialize(ifname, ispec, arg_check: false)
      mod_name, class_name = Util.ifname_to_cname ifname
      @ifname = ifname
      @mod_name = mod_name
      @class_name = class_name
      @ispec = ispec
      @arg_check = arg_check
    end
    attr_reader :mod_name, :class_name, :ispec, :ifname, :arg_check

    def generate
      template_file = File.join File.dirname(__FILE__), TEMPLATE_FILE_NAME
      template = File.read template_file
      erb = ERB.new template, trim_mode: '%'
      erb.result binding
    end

    def args_string(args)
      ary = []
      new_id = false
      args.each do |a|
        case a[:type]
        when :int, :uint, :object, :string, :array, :fd
          ary << a[:name]
        when :new_id
          ary << a[:name] unless a[:interface]
          new_id = true
        end
      end
      ary << "as: nil" if new_id
      ary.join(', ')
    end

    def pack_template_char(type)
      TYPE_TEMPLATE_CHAR[type]
    end

    def message_base_size(args)
      args.inject(8 << 16) do |r, a|
        r + case a[:type]
            when :string, :array, :fd
              0
            else
              4 << 16
            end
      end
    end
  end
end

if __FILE__ == $0
  require 'yaml'
  def usage
    STDERR.puts "usage: #{$0} yaml_path"
    exit 1
  end
  yaml_path = ARGV.shift
  usage if yaml_path.nil? || !File.exist?(yaml_path)
  yaml = File.join yaml_path
  data = YAML.load_file yaml
  data.each do |ifname, ispec|
    gen = Wayland::CodeGenerator.new ifname, ispec
    print gen.generate
  end
end
