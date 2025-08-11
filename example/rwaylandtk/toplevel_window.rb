require 'rwaylandtk/custom_wl_interface'

module RWaylandTk

  class ToplevelWindow

    include CustomWaylandInterface

    def initialize(width, height)
      @display = RWaylandTk.display_instance
      @width = width
      @height = height
      @valid = false
      @wl_surface = @display[:wl_compositor].create_surface as: [WlSurface, self]
      @xdg_surface = @display[:xdg_wm_base].get_xdg_surface @wl_surface, as: [XdgSurface, self]
      @xdg_toplevel = @xdg_surface.get_toplevel as: [XdgToplevel, self]
    end
    attr_reader :width, :height

    # User hook

    def mouse_enter(x, y);                end
    def mouse_leave;                      end
    def mouse_moved(x, y);                end
    def mouse_up(button, time, serial);   end
    def mouse_down(button, time, serial); end
    def axis(time, axis, value)         ; end
    def resized(width, height);           end
    def key_down(data);                   end
    def key_up(data);                     end

    BGCOLOR = [1.0, 1.0, 1.0, 1.0]

    def draw
      cairo = cairo_context
      cairo.save do
        cairo.set_source_color BGCOLOR
        cairo.rectangle 0, 0, width, height
        cairo.fill
      end
    end

    # Hook

    def _mouse_enter(x, y)
      # p [:mouse_enter, x, y]
      mouse_enter x, y
      # update_if_needed
    end

    def _mouse_leave
      # p [:mouse_leave]
      mouse_leave
      # update_if_needed
    end

    def _mouse_moved(x, y)
      mouse_moved x, y
      update_if_needed
    end

    def _mouse_up(button, time, serial)
      mouse_up(button, time, serial)
      update_if_needed
    end

    def _mouse_down(button, time, serial)
      mouse_down(button, time, serial)
      update_if_needed
    end

    def _axis(time, axis, value)
      axis(time, axis, value)
      update_if_needed
    end

    def _resize(width, height)
      if width > 0 && height > 0
        @width = width
        @height = height
        resized width, height
        update_if_needed
      end
    end

    def _frame_done
      @frame_requested = false
      realloc_buffer
      draw
      _expose
    end

    def _expose
      @wl_surface.attach @wl_buffer, 0, 0
      @wl_buffer.attached
      @wl_surface.damage_buffer 0, 0, 0x7fffffff, 0x7fffffff
      @wl_surface.commit
      validate
    end

    def _configure(serial)
    end

    def _key_down(data)
      key_down(data)
      update_if_needed
    end

    def _key_up(data)
      key_up(data)
      update_if_needed
    end

    # API

    def cairo_context
      @wl_buffer.cairo_context
    end

    def request_frame
      unless @frame_requested
        @wl_surface.frame as: [FrameCB, self]
        @wl_surface.commit
        @frame_requested = true
      end
    end

    def update_if_needed
      return if valid?
      request_frame
    end

    def set_title(title, app_id, commit = true)
      @xdg_toplevel.set_title title
      @xdg_toplevel.set_app_id app_id
      @wl_surface.commit if commit
      @title = title
      @app_id = app_id
    end
    attr_reader :title, :app_id

    def bpp; 4 end # pseudo

    def buffer_realloc?
      return false if width == 0 || height == 0
      return true unless @wl_buffer
      return true if @wl_buffer.attached?
      return false if @wl_buffer.width == width && @wl_buffer.height == height
      return true
    end

    def realloc_buffer
      if buffer_realloc?
        stride = width * bpp
        size = stride * height
        shm = Wayland::SharedMemory.new size: size
        pool = @display[:wl_shm].create_pool shm.fd, size
        format = Wayland::Wl::Shm[:format].xrgb8888
        buffer = pool.create_buffer(0, width, height, stride, format,
                                    as: [WlBuffer, width, height, stride, format, shm])
        pool.destroy
        shm.close
        @wl_buffer.destroy_on_release if @wl_buffer
        cairo = buffer.cairo_context
        cairo.save do
          cairo.set_source_color BGCOLOR
          cairo.rectangle 0, 0, width, height
          cairo.fill
        end
        @wl_buffer = buffer
      end
      @wl_buffer
    end

    def invalidate
      @valid = false
    end      

    def validate
      @valid = false
    end

    def valid?
      @valid
    end

    def show
      invalidate
      realloc_buffer
      draw
      _expose
    end
  end
end
