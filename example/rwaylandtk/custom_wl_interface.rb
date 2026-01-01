require 'wayland'
require 'wayland/cairo_support'
require 'wayland/xkb_support'

module RWaylandTk
  module CustomWaylandInterface
    class WlSurface < Wayland::Wl::Surface
      def post_init(window)
        @window = window
      end
      attr_reader :window
    end

    class XdgToplevel < Wayland::Xdg::Toplevel
      def post_init(window)
        @window = window
      end

      def configure(width, height, state)
        @window._resize(width, height)
      end
    end

    class XdgSurface < Wayland::Xdg::Surface
      def post_init(window)
        @window = window
      end

      def configure(serial)
        ack_configure serial
        @window._configure serial
      end
    end

    class WlBuffer < Wayland::Wl::Buffer
      def post_init(width, height, stride, format, shared_memory)
        @width = width
        @height = height
        @stride = stride
        @format = format
        @shared_memory = shared_memory
      end
      attr_reader :width, :height, :stride, :format

      def destroy_on_release
        @destroy_on_release = true
        destroy if @attached == false
      end

      def attached
        @attached = true
      end

      def release
        @attached = false
        destroy if @destroy_on_release
      end

      def attached?
        @attached
      end

      def cairo_surface
        @cairo_surface ||=
          Wayland::CairoSupport.create_image_surface_for_shared_memory(@shared_memory, 0, 0,
                                                                       @width, @height, @stride)
      end

      def cairo_context
        @cairo_context ||= Cairo::Context.new cairo_surface
      end
    end

    module WlPointer
      def enter(serial, surface, x, y)
        @surface = surface
        surface.window._mouse_enter x, y
      end

      def leave(serial, surface)
        surface.window._mouse_leave
        @surface = nil
      end

      def motion(time, x, y)
        @surface&.window._mouse_moved x, y
      end

      def button(serial, button, time, state)
        case state
        when Wayland::Wl::Pointer[:button_state].pressed
          @surface&.window._mouse_down(button, time, serial)
        when Wayland::Wl::Pointer[:button_state].released
          @surface&.window._mouse_up(button, time, serial)
        end
      end

      def axis(time, axis, value)
        @surface&.window._axis(time, axis, value)
      end
    end

    module WlKeyboard
      def keymap(fmt, fd, size)
        case fmt
        when Wayland::Wl::Keyboard[:keymap_format].no_keymap
          fd.close
        when Wayland::Wl::Keyboard[:keymap_format].xkb_v1
          shm = Wayland::SharedMemory.new fd, size: size, prot: Wayland::SharedMemory::PROT_READ
          @xkb_ctx = Wayland::Xkb::Context.new
          @xkb_keymap = @xkb_ctx.keymap_new_from_string(shm.address,
                                                        Wayland::XkbSupport::XKB_KEYMAP_FORMAT_TEXT_V1,
                                                        Wayland::XkbSupport::XKB_KEYMAP_COMPILE_NO_FLAGS)
          @xkb_state = @xkb_keymap.state_new
        else
          raise "unknonw keymap format received #{fmt}"
        end
      end

      def enter(serial, surface, keys)
        @surface = surface
        if keys
          keys.each_byte do |b|
            s = @xkb_state.key_get_one_sym(b + 8)
          end
        end
      end

      def leave(serial, surface)
      end

      def key(serial, time, key, state)
        s = @xkb_state.key_get_one_sym(key + 8)
        # buff = "\0" * 128
        # len, buffer = @xkb_state.key_get_utf8(key + 8, buff)
        # data = buff.byteslice(0, len)
        if state == 1
          @surface.window&._key_down s
        else
          @surface.window&._key_up s
        end
      end

      def modifiers(serial, mods_depressed, mods_latched, mods_locked, group)
        @xkb_state.update_mask(mods_depressed, mods_latched, mods_locked, 0, 0, group)
      end
    end

    module WlSeat
      def capabilities(caps)
        if (caps & Wayland::Wl::Seat[:capability][:pointer] != 0)
          get_pointer as: WlPointer
        end
        if (caps & Wayland::Wl::Seat[:capability][:keyboard] != 0)
          get_keyboard as: WlKeyboard
        end
      end
    end

    module WlRegistry
      def global(name, interface, version)
        if interface == "wl_seat"
          intf = Wayland::Protocol[:wl_seat]
          bind name, interface, [version, intf[:version]].min, :wl_seat, as: WlSeat
        else
          super
        end
      end
    end

    class FrameCB < Wayland::Wl::Callback
      def post_init(window)
        @window = window
      end

      def done(callback_data)
        @window._frame_done
      end
    end
  end
end
