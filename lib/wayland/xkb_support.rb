require 'fiddle/import'

module Wayland
  module XkbSupport
    XKB_CONTEXT_NO_FLAGS = 0
    XKB_CONTEXT_NO_DEFAULT_INCLUDES = (1 << 0)
    XKB_CONTEXT_NO_ENVIRONMENT_NAMES = (1 << 1)
    XKB_CONTEXT_NO_SECURE_GETENV = (1 << 2)
    XKB_KEYMAP_FORMAT_TEXT_V1 = 1
    XKB_KEYMAP_COMPILE_NO_FLAGS = 0
    module F
      extend Fiddle::Importer
      dlload "libxkbcommon.so.0"
      extern "void *xkb_context_new(int)"
      extern "void *xkb_context_ref(void *)"
      extern "void  xkb_context_unref(void *)"
      extern "void  xkb_context_set_user_data(void *, void *)"
      extern "void *xkb_context_get_user_data(void *)"

      extern "void *xkb_keymap_new_from_string(void *, void *, int, int)"
      extern "void *xkb_keymap_ref(void *)"
      extern "void  xkb_keymap_unref(void *)"

      extern "void *xkb_state_new(void *)"
      extern "void *xkb_state_ref(void *)"
      extern "void  xkb_state_unref(void *)"
      extern "unsigned int xkb_state_key_get_one_sym(void *, unsigned int)"
      extern "int xkb_state_key_get_utf8(void *, int, void *, size_t)"
      extern "unsigned int xkb_state_update_mask(void *, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int)"
    end
  end

  module Xkb
    class Context
      def initialize(flags = XkbSupport::XKB_CONTEXT_NO_FLAGS)
        @pointer = XkbSupport::F.xkb_context_new flags
        @pointer.free = XkbSupport::F[:xkb_context_unref]
      end

      def keymap_new_from_string(source, format, flags)
        ptr = XkbSupport::F.xkb_keymap_new_from_string(@pointer, source, format, flags)
        ptr.free = XkbSupport::F[:xkb_keymap_unref]
        obj = Keymap.new
        obj.instance_eval do
          @context = self
          @pointer = ptr
        end
        obj
      end
    end

    class Keymap
      def state_new
        ptr = XkbSupport::F.xkb_state_new @pointer
        ptr.free = XkbSupport::F[:xkb_state_unref]
        obj = State.new
        obj.instance_eval do
          @state = self
          @pointer = ptr
        end
        obj
      end
    end

    class State
      def key_get_one_sym(scancode)
        XkbSupport::F.xkb_state_key_get_one_sym(@pointer, scancode)
      end

      def key_get_utf8(scancode, buffer = nil)
        unless buffer
          len = XkbSupport::F.xkb_state_key_get_utf8(@pointer, scancode, nil, 0)
          buffer = "\0" * (len + 1)
        end
        len = XkbSupport::F.xkb_state_key_get_utf8(@pointer, scancode,
                                                   buffer, buffer.bytesize)
        return len, buffer
      end

      def update_mask(depressed_mods, latched_mods, locked_mods,
                      depressed_layout, latched_layout, locked_layout)
        XkbSupport::F.xkb_state_update_mask(@pointer,
                                            depressed_mods, latched_mods, locked_mods,
                                            depressed_layout, latched_layout, locked_layout)
      end
    end
  end
end
