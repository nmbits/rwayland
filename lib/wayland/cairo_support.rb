require "cairo"
require "fiddle/import"
require "wayland/shared_memory"

module Wayland
  module CairoSupport
    module F
      extend Fiddle::Importer
      cairo_so = $".find {|f| File.basename(f) == "cairo.so" }
      raise "cairo.so not found" unless cairo_so
      dlload cairo_so
      extern "void *cairo_image_surface_create_for_data(void *, int, int, int, int)"
      addr = handler.sym "rb_cairo_surface_to_ruby_object"
      RB_CAIRO_SURFACE_TO_RUBY_OBJECT =
        Fiddle::Function.new(addr, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_UINTPTR_T, need_gvl: true)
      module_function
      def rb_cairo_surface_to_ruby_object(adr)
        RB_CAIRO_SURFACE_TO_RUBY_OBJECT.call adr
      end
    end

    module_function

    def create_image_surface_for_shared_memory(shared_memory, offset, type,
                                               width, height, stride)
      data = shared_memory.address + offset
      surfacep = F.cairo_image_surface_create_for_data(data, type, width, height, stride)
      if surfacep.to_i != 0
        value = F.rb_cairo_surface_to_ruby_object(surfacep)
        obj = Fiddle.dlunwrap(value)
        obj.instance_variable_set :@__shared_memory, shared_memory
        obj
      end
    end
  end
end
