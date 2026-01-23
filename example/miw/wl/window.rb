require "miw/rectangle"
require "miw/size"
require "miw/wl"
require "miw/wl/private"

module MiW
  module Wl
    class Window

      PIXEL_BLOCK_SIZE = 256

      # Initializer.
      #
      # +client+  :: client
      # +width+   :: client width
      # +height+  :: client height
      #
      def initialize(client, width, height)
        raise ArgumentError, "width and height should be greater than 0" if width <= 0 || height <= 0
        @init_size   = Size.new(width.to_i, height.to_i)
        @states  = 0
        @client = client
        @display = Wl.display_instance
        @wl_surface = @display[:wl_compositor].create_surface as: [Private::WlSurface, self]
        @xdg_surface = @display[:xdg_wm_base].get_xdg_surface @wl_surface, as: [Private::XdgSurface, self]
      end
      attr_reader :states
      attr_reader :surface_geometry
      attr_reader :invalid_rect

      def client_size
        @client_geometry&.size || Size.new(0, 0)
      end

      # Byte per pixel.
      #
      def bpp; 4 end # pseudo

      # True if wl_shm_pool should be (re)allocated.
      # 
      private def pool_realloc?
        return true if @wl_shm_pool.nil?
        return true if @wl_buffur&.busy?
        return true if width  > @wl_shm_pool.width
        return true if height > @wl_shm_pool.height
        pblks = (@wl_shm_pool.width + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE
        if pblks > 1
          wblks = (width + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE
          return true if wblks <= pblks / 2
        end
        pblks = (@wl_shm_pool.height + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE
        if pblks > 1
          wblks = (height + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE
          return true if wblks <= pblks / 2
        end
        return false
      end

      # (Re)allocate a wl_shm_pool instance.
      # 
      private def realloc_pool
        if pool_realloc?
          return nil if width == 0 || height == 0     #TODO
          pw = (width  + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE * PIXEL_BLOCK_SIZE
          ph = (height + PIXEL_BLOCK_SIZE - 1) / PIXEL_BLOCK_SIZE * PIXEL_BLOCK_SIZE
          @wl_shm_pool&.destroy
          @wl_shm_pool = Private::WlShmPool.create @display, pw, ph, bpp
        end
        @wl_shm_pool
      end

      # True if wl_buffer should be (re)allocated.
      #
      private def buffer_realloc?
        return false if width == 0 || height == 0
        return true  if @wl_buffer.nil?
        return true  if @wl_shm_pool != @wl_buffer.pool
        return true  if @wl_buffer.width != width || @wl_buffer.height != height
        return true  if @wl_buffer.busy?
        return false
      end

      # (Re)allocate wl_buffer.
      #
      private def realloc_buffer
        pool = realloc_pool
        if buffer_realloc?
          @wl_buffer&.lasy_destroy
          @wl_buffer = Private::WlBuffer.create pool, width, height, Wayland::Wl::Shm[:format].argb8888
          @invalid_rect = Rectangle.new(0, 0, width, height)
        end
        @wl_buffer
      end

      # Request wl_surface#commit.
      #
      def commit_now
        @wl_surface.commit
        @need_commit = false
      end

      #
      #
      def lasy_commit
        @need_commit = true
      end

      def commit_if_needed
        commit_now if @need_commit
      end

      # Request wl_surface#frame.
      #
      def lasy_update
        if invalid? && !@frame_requested
          @frame_requested = true
          @wl_surface.frame as: [Private::FrameCB, self]
          lasy_commit
        end
      end

      def update
        if invalid?
          realloc_buffer
          draw
          @wl_surface.attach @wl_buffer
          @wl_surface.damage_buffer(@invalid_rect.x,     @invalid_rect.y,
                                    @invalid_rect.width, @invalid_rect.height)
          @invalid_rect = nil
          lasy_commit
          commit_now
        end
      end

      def draw
        cairo = Cairo::Context.new @wl_buffer.cairo_image_surface
        cairo.save { draw_nonclient cairo }
        cairo.save { draw_client cairo }
      end

      private def draw_client(cairo)
        rect = convert_to_client @invalid_rect.dup.intersect(@client_geometry)
        if rect.width > 0 && rect.height > 0
          cairo.translate @client_geometry.x, @client_geometry.y
          cairo.rectangle 0, 0, @client_geometry.width, @client_geometry.height
          cairo.clip
          @client.draw cairo, rect
        end
      end

      private def draw_nonclient(cairo)
      end

      def invalid?
        @invalid_rect&.valid?
      end

      # Mark rectangle area as invalid. Request wl_surfae#frame.
      #
      # +x+ :: left
      # +y+ :: top
      # +w+ :: width
      # +h+ :: height
      def invalidate(x, y, w, h)
        if @invalid_rect
          @invalid_rect.union x, y, w, h
        else
          @invalid_rect = Rectangle.new(x, y, w, h)
        end
      end

      def invalidate_all
        invalidate(0, 0, width, height)
      end

      def invalidate_client(cx, cy, w, h)
        cr = Rectangle.new(cx, cy, w, h)
        wr = convert_to_window(cr).intersect @client_geometry
        invalidate wr.x, wr.y, wr.width, wr.height if wr.valid?
      end

      # event hooks

      ## FrameCB

      def on_framecb_done(time)
        @frame_requested = false
        update
      end

      ## WlPointer

      def on_wl_pointer_enter(serial, x, y)
        @serial = serial
        @pointer_x = x
        @pointer_y = y
        cx, cy = convert_to_client x, y
        @client.pointer_enter cx, cy
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_leave(serial)
        @serial = serial
        @client.pointer_leave
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_motion(time, x, y)
        @poitner_x = x
        @poitner_y = y
        cx, cy = convert_to_client x, y
        @client.pointer_motion time, cx, cy
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_button(serial, time, button, state)
        @serial = serial
        @client.pointer_button(time, button, state)
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_axis(time, axis, value)
      end

      def set_default_cursor(serial, loc)
        name = case loc
               when :top_left
                 "nw-resize"
               when :top
                 "n-resize"
               when :top_right
                 "ne-resize"
               when :left
                 "w-resize"
               when :right
                 "e-resize"
               when :bottom_left
                 "sw-resize"
               when :bottom
                 "s-resize"
               when :bottom_right
                 "se-resize"
               else
                 "arrow"
               end
        surface, hx, hy = MiW::Wl.cursor_surface name
        if surface && @prev_name != name
          @prev_name = name
          @display[:wl_pointer].set_cursor serial, surface, hx, hy
        end
      end

      def reset_cursor
        @prev_name = nil
      end

      def on_wl_keyboard_key(serial, time, keysym, state)
        @client.keyboard_key(time, keysym, state)
        lasy_update
        commit_if_needed
      end
      # convert

      def convert_to_client(wx, wy = nil)
        if wy.nil?
          wx.dup.offset_by -@client_geometry.x, -@client_geometry.y
        else
          return wx - @client_geometry.x, wy - @client_geometry.y
        end
      end

      def convert_to_window(cx, cy = nil)
        if cy.nil?
          cx.dup.offset_by @client_geometry.x, @client_geometry.y
        else
          return cx + @client_geometry.x, cy + @client_geometry.y
        end
      end

      def pulse
        @client&.pulse
      end

      def hit_test(x, y)
        :client
      end

      # control methods

      def show
      end

      def hide
      end

      def minimize
      end

      def title=(title)
      end

      def title
      end

      def surface
      end

      def sync
      end

      def size
      end

      def move_to
      end

      def resize_to(width, height)
        @surface_geometry ||= Rectangle.new(0, 0, 0, 0)
        @surface_geometry.resize_to width, height
      end

      def width
        @surface_geometry.width
      end

      def height
        @surface_geometry.height
      end

      def quit_requested
      end
    end
  end
end
