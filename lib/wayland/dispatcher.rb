require 'wayland/wlobject'
require 'wayland/protocol'
require 'wayland/message_buffer'

module Wayland
  class Dispatcher
    GUARD = Object.new.freeze
    def initialize(wl_display)
      @phase = :header
      @buffer = MessageBuffer.new
      @ios = []
      @display = wl_display
    end

    def feed(data, ios)
      raise "closed" if @close_requested
      count = 0
      @buffer.write data
      @ios.concat ios
      loop do
        case @phase
        when :header
          break if @buffer.bytesize < 8
          @oid = @buffer.read_object
          opsz = @buffer.read_uint
          @opcode = opsz & 0xffff
          @size = (opsz >> 16) - 8
          next if @oid == 0
          @phase = :args
        when :args
          break if @buffer.bytesize < @size
          dispatch @oid, @opcode, @buffer, @size
          count += 1
          @phase = :header
          break if @close_requested
        end
      end
      # Wayland.logger.debug "feed: #{@buffer.bytesize}"
      count
    end

    def dispatch(oid, op, buffer, size)
      object = @display.get_object oid
      raise "object 0x#{@oid.to_s(16)} not found" unless object
      intf = Protocol[object.ifname]
      evs = intf[:events]
      ev = evs ? evs[op] : nil
      unless ev
        pp [op, object.ifname, evs]
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
          @display.get_object buffer.read_object
        when :fixed
          buffer.read_fixed
        when :new_id
          @display.create_object a[:interface], buffer.read_object
        when :string
          buffer.read_string
        when :array
          buffer.read_array
        when :fd
          @ios.shift || raise("no io for fd arg")
        end
      end
      f = object.respond_to?(name) && !GUARD.respond_to?(name)
      @display.event_log f, oid, object.ifname, name, *args
      object.__send__ name, *args if f
    end

    def close
      @buffer.clear
      @close_requested = true
    end
  end
end
