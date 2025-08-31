require 'wayland/protocol'

module Wayland
  class WLObject
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
  end
end
