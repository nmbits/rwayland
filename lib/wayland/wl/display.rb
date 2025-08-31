require 'socket'
require 'wayland/wlobject'
require 'wayland/dispatcher'
require 'wayland/free_list'
require 'wayland/object_manager'
require 'wayland/util'

module Wayland
  module Wl
    class Display < WLObject
      XDG_RUNTIME_DIR = "XDG_RUNTIME_DIR"
      WAYLAND_DISPLAY = "WAYLAND_DISPLAY"
      WAYLAND_DISPLAY_DEFAULT = "wayland-0"

      def initialize(wl_object_id)
        super wl_object_id, self
        @dispatcher = Dispatcher.new self
      end

      def dispatch(timeout = nil)
        count = 0
        rd = [@socket]
        ios = []
        loop do
          if IO.select(rd, [], [], timeout)
            str, addr, int, *ctls = @socket.recvmsg(256, 0, nil, :scm_rights => true)
            ctls.each do |a|
              if a.cmsg_is?(:SOCKET, :RIGHTS)
                a.unix_rights.each{|io| ios << io }
              end
            end
            count = @dispatcher.feed str, ios
            ios.clear
          end
          break if count > 0 || timeout
        end
        count
      end

      def roundtrip
        fin = false
        sync.on(:done){|cbdata| fin = true }
        dispatch until fin
      end

      def error(object, code, message)
        ifname = object&.ifname || "(null)"
        oid = object.wl_object_id
        soid = sprintf("0x%08x", oid)
        raise "fatal error event received: object = #{soid}(#{ifname}), code = #{code}, #{message}"
      end

      def delete_id(oid)
        @object_manager.delete_id oid
      end

      def get_default_impl(ifname)
        mname, cname = Util.ifname_to_cname ifname
        raise ArgumentError unless Wayland.const_defined? mname
        n = Wayland.const_get mname
        raise ArgumentError unless n.const_defined? cname
        n.const_get cname
      end
      private :get_default_impl

      def get_impl(ifname, mod)
        c = get_default_impl(ifname)
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

      def create_object(ifname, oid, mod = nil)
        @object_manager.create_object ifname, oid, mod
      end

      def get_object(oid)
        @object_manager.get_object oid
      end

      def get_objects_by_ifname(ifname)
        @object_manager.get_objects_by_ifname ifname
      end

      def get_first_object_by_ifname(ifname)
        @object_manager.get_first_object_by_ifname ifname
      end

      def [](key)
        @object_manager[key]
      end

      def sendmsg(message, ancdata = nil)
        if ancdata
          @socket.sendmsg message, 0, nil, ancdata
        else
          @socket.sendmsg message, 0, nil
        end
      end

      ZERO4 = "\0" * 4

      # append zero to +str+ to be 4B aligned
      #
      # +str+   :: string
      # +zterm+ :: returns zero terminated string
      # +return+ :: string size
      #
      def pad_string(str, zterm)
        len = str.bytesize
        pad = 4 - (len % 4)
        if pad == 4 && (!zterm || str.getbyte(-1) == 0)
          str
        else
          str.bytesplice(len, pad, ZERO4, 0, pad)
        end
      end

      def send_request(wlobj, sym, rspec, *margs, as: nil)
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
            str = pad_string margs[i], arg[:type] == :string
            str_size = str.bytesize
            size += (str_size + 4) << 16
            alist << str_size
            alist << str
            i += 1
          when :new_id
            interface = arg[:interface]
            if interface
              obj = create_object interface, nil, as
            else
              obj = create_object margs[i], nil, as
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
        if ancdata
          sendmsg message, ancdata
        else
          sendmsg message
        end
        request_log wlobj, sym, *alist
        return obj
      end

      def disconnect
        if @socket
          @dispatcher.close
          @socket.close
          @socket = nil
        end
      end

      def set_socket(socket)
        @socket = socket
      end

      def set_object_manager(object_manager)
        @object_manager = object_manager
      end

      def set_logger(logger)
        @logger = logger
      end

      def event_log(recv, oid, ifname, name, *args)
        if @logger
          args0 = args.map{|a| WLObject === a ? "##{a.wl_object_id}" : a}
          @logger.debug "#{recv ? 'EV' : 'ev'}: (#{oid}) #{ifname}::#{name} #{args0}"
        end
      end

      def request_log(obj, name, *a)
        @logger&.debug "RQ: (#{obj.wl_object_id}) #{obj.ifname}::#{name} #{a}"
      end

      def create_log(obj)
        @logger&.debug "CO: (#{obj.wl_object_id}) #{obj.ifname}"
      end

      def delete_log(obj)
        @logger&.debug "DO: (#{obj.wl_object_id}) #{obj.ifname}"
      end

      def self.connect(name = nil, as: nil)
        xdg_runtime_dir = ENV[XDG_RUNTIME_DIR]
        name ||= ENV[WAYLAND_DISPLAY]
        name ||= WAYLAND_DISPLAY_DEFAULT
        if xdg_runtime_dir.nil? || xdg_runtime_dir.empty?
          path = name
        else
          path = File.join(xdg_runtime_dir, name)
        end
        socket = UNIXSocket.new(path)
        object_manager = ObjectManager.new
        inst = object_manager.create_wl_display socket, as
        inst
      end
    end
  end
end
