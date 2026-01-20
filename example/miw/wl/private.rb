require 'wayland'
require 'wayland/shared_memory'
require 'wayland/cairo_support'
require 'wayland/xkb_support'

module MiW
  module Wl
    module Private
      class WlSurface < Wayland::Wl::Surface
        def post_init(window)
          @window = window
        end
        attr_reader :window

        def attach(buffer)
          @buffer = buffer
          buffer.attached
          super buffer, 0, 0
        end

        def commit
          @buffer&.committed
          super
        end
      end

      class XdgSurface < Wayland::Xdg::Surface
        def post_init(window)
          @window = window
        end

        def configure(serial)
          ack_configure serial
          @window.on_xdg_surface_configure(serial)
        end
      end

      class XdgPopup < Wayland::Xdg::Popup
        def post_init(window)
          @window = window
        end

        def configure(x, y, width, height)
          @x = x
          @y = y
          @width = width
          @height = height
        end
        attr_reader :x, :y, :width, :height

        def popup_done
          @window.on_xdg_popup_popup_done
        end

        def repositioned(token)
          @window.on_xdg_popup_repositioned token
        end
      end

      class WlShmPool < Wayland::Wl::ShmPool
        def post_init(width, height, bpp, shared_memory)
          @width = width
          @height = height
          @bpp = bpp
          @shared_memory = shared_memory
        end
        attr_reader :width, :height, :bpp, :shared_memory

        def stride
          @width * @bpp
        end

        def self.create(display, width, height, bpp)
          stride = width * bpp
          size = stride * height
          shm = Wayland::SharedMemory.new size: size
          pool = display[:wl_shm].create_pool shm.fd, size, as: [self, width, height, bpp, shm]
        end
      end

      class WlBuffer < Wayland::Wl::Buffer
        def post_init(width, height, format, pool)
          @width  = width
          @height = height
          @format = format
          @pool   = pool
        end
        attr_reader :width, :height, :format, :pool

        def destroy_now
          unless @destroyed
            @destroyed = true
            destroy
          end
        end

        def attached
          @attached = true
        end

        def committed
          @committed = true
        end

        def release
          @attached = false
          @committed = false
          destroy_now if @destroy_on_release
        end

        def busy?
          @attached && @committed
        end

        def lasy_destroy
          @destroy_on_release = true
          destroy_now unless busy?
        end

        def cairo_image_surface
          @cairo_surface ||=
            Wayland::CairoSupport.create_image_surface_for_shared_memory(@pool.shared_memory, 0, 0,
                                                                         @width, @height, @pool.stride)
        end

        def self.create(pool, width, height, format)
          pool.create_buffer(0, width, height, pool.stride, format,
                             as: [self, width, height, format, pool])
        end
      end

      class WlPointer < Wayland::Wl::Pointer
        def enter(serial, surface, x, y)
          @surface = surface
          surface.window.on_wl_pointer_enter serial, x, y
        end

        def leave(serial, surface)
          surface.window.on_wl_pointer_leave serial
          @surface = nil
        end

        def motion(time, x, y)
          @surface.window.on_wl_pointer_motion time, x, y if @surface
        end

        def button(serial, button, time, state)
          @surface.window.on_wl_pointer_button serial, button, time, state if @surface
        end

        def axis(time, ax, value)
          @surface.window.on_wl_pointer_axis time, ax, value if @surface
        end
      end

      class WlKeyboard < Wayland::Wl::Keyboard
        def keymap(fmt, fd, size)
          if fmt != Wayland::Wl::Keyboard[:keymap_format].xkb_v1
            raise "unknonw keymap format received"
          end
          shm = Wayland::SharedMemory.new fd, size: size, prot: Wayland::SharedMemory::PROT_READ
          @xkb_ctx = Wayland::Xkb::Context.new
          @xkb_keymap = @xkb_ctx.keymap_new_from_string(shm.address,
                                                        Wayland::XkbSupport::XKB_KEYMAP_FORMAT_TEXT_V1,
                                                        Wayland::XkbSupport::XKB_KEYMAP_COMPILE_NO_FLAGS)
          @xkb_state = @xkb_keymap.state_new
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
          @surface.window&.on_wl_keyboard_key(serial, time, s, state)
        end

        def modifiers(serial, mods_depressed, mods_latched, mods_locked, group)
          @xkb_state.update_mask(mods_depressed, mods_latched, mods_locked, 0, 0, group)
        end
      end

      class WlSeat < Wayland::Wl::Seat
        def capabilities(caps)
          if (caps & Wayland::Wl::Seat[:capability][:pointer] != 0)
            get_pointer as: WlPointer
          end
          if (caps & Wayland::Wl::Seat[:capability][:keyboard] != 0)
            get_keyboard as: WlKeyboard
          end
        end
      end

      class FrameCB < Wayland::Wl::Callback
        def post_init(window)
          @window = window
        end

        def done(data)
          @window.on_framecb_done data
        end
      end

      class XdgToplevel < Wayland::Xdg::Toplevel
        def post_init(window)
          @window = window
        end

        def configure(width, height, states)
          @width  = width
          @height = height
          @states = states&.unpack("L*") || []
        end

        def configure_bounds(width, height)
          @bounds_width  = width
          @bounds_height = height
        end
        attr_reader :width, :height, :states,
                    :bounds_width, :bounds_height
      end
    end # Private
  end # Wl
end
