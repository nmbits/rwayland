require "miw/wl/window"
require "miw/wl/private"

module MiW
  module Wl

    BORDER_WIDTH    = 8
    TITLEBAR_HEIGHT = 40

    class Toplevel < Window

      STATE_MAXIMIZED    = 1 << 1
      STATE_FULLSCREEN   = 1 << 2
      STATE_RESIZING     = 1 << 3
      STATE_ACTIVATED    = 1 << 4
      STATE_TILED_LEFT   = 1 << 5
      STATE_TILED_RIGHT  = 1 << 6
      STATE_TILED_TOP    = 1 << 7
      STATE_TILED_BOTTOM = 1 << 8
      STATE_SUSPTENDED   = 1 << 9
      STATE_CONSTRAINED_LEFT   = 1 << 10
      STATE_CONSTRAINED_RIGHT  = 1 << 11
      STATE_CONSTRAINED_TOP    = 1 << 12
      STATE_CONSTRAINED_BOTTOM = 1 << 13

      STATES_RESIZED = (STATE_MAXIMIZED | STATE_FULLSCREEN | STATE_RESIZING |
                        STATE_TILED_LEFT | STATE_TILED_RIGHT | STATE_TILED_TOP | STATE_TILED_BOTTOM |
                        STATE_CONSTRAINED_LEFT | STATE_CONSTRAINED_RIGHT | STATE_CONSTRAINED_TOP | STATE_CONSTRAINED_BOTTOM)

      BTN_MOUSE   = 0x110
      BTN_LEFT    = 0x110
      BTN_RIGHT   = 0x111
      BTN_MIDDLE  = 0x112
      BTN_SIDE    = 0x113
      BTN_EXTRA   = 0x114
      BTN_FORWARD = 0x115
      BTN_BACK    = 0x116
      BTN_TASK    = 0x117

      class ClientDecoration
        def initialize(toplevel)
          @toplevel = toplevel
        end

        def border_left?(states)
          (states & (STATE_MAXIMIZED | STATE_FULLSCREEN | STATE_TILED_LEFT | STATE_CONSTRAINED_LEFT)) == 0
        end

        def border_right?(states)
          (states & (STATE_MAXIMIZED | STATE_FULLSCREEN | STATE_TILED_RIGHT | STATE_CONSTRAINED_RIGHT)) == 0
        end

        def border_top?(states)
          (states & (STATE_MAXIMIZED | STATE_FULLSCREEN | STATE_TILED_TOP | STATE_CONSTRAINED_TOP)) == 0
        end

        def border_bottom?(states)
          (states & (STATE_MAXIMIZED | STATE_FULLSCREEN | STATE_TILED_BOTTOM | STATE_CONSTRAINED_BOTTOM)) == 0
        end

        def fullscreen?(states)
          (states & STATE_FULLSCREEN) > 0
        end

        def title_bar?(states)
          !fullscreen?(states)
        end

        def adjust_window_geometry(rec_width, rec_height, bounds_width, bounds_height, states)
          bw = bounds_width  || Float::INFINITY
          bh = bounds_height || Fload::INFINITY

          # initial size
          iw = rec_width
          ih = rec_height

          # window size
          ww = [iw, bw].min
          wh = [ih, bh].min

          # widow geometry
          wx = border_left?(states) ? BORDER_WIDTH : 0
          wy = border_top?(states)  ? BORDER_WIDTH : 0

          Rectangle.new wx, wy, ww, wh
        end

        # Descide surface size and window geometry based on init_size
        #
        def initial_window_geometry(client_width, client_height, bounds_width, bounds_height, states)
          # initial size
          iw = client_width
          ih = client_height

          unless fullscreen?(states)
            ih += TITLEBAR_HEIGHT
          end

          adjust_window_geometry iw, ih, bounds_width, bounds_height, states
        end

        def adjust_client_geometry(client_geometry, window_geometry, states)
          client_geometry.x      = window_geometry.x
          client_geometry.y      = window_geometry.y
          client_geometry.width  = window_geometry.width
          client_geometry.height = window_geometry.height
          if title_bar? states
            client_geometry.y      += TITLEBAR_HEIGHT
            client_geometry.height -= TITLEBAR_HEIGHT
          end
        end

        def adjust_surface_size(window, window_geometry, states)
          sw = window_geometry.width
          sh = window_geometry.height
          sw += BORDER_WIDTH if border_left? states
          sw += BORDER_WIDTH if border_right? states
          sh += BORDER_WIDTH if border_top? states
          sh += BORDER_WIDTH if border_bottom? states
          window.resize_to sw, sh
        end

        #
        #
        def box_rect(wgeo, type, states)
          return nil unless title_bar? states
          case type
          when :minimize
            n = 3
          when :maximize
            n = 2
          when :close
            n = 1
          else
            return nil
          end
          Rectangle.new wgeo.right - TITLEBAR_HEIGHT * n, wgeo.y, TITLEBAR_HEIGHT, TITLEBAR_HEIGHT
        end

        # Draw non client area
        #
        # +cairo+     :: Cairo::Context
        #
        def draw(cairo)
          sgeo   = @toplevel.surface_geometry
          wgeo   = @toplevel.window_geometry
          drect  = @toplevel.invalid_rect
          states = @toplevel.states

          cairo.save do
            cairo.rectangle *drect
            cairo.clip
            cairo.operator = Cairo::Operator::SOURCE
            cairo.set_source_rgba 0, 0, 0, 0
            # left
            if wgeo.x > 0 && drect.x <= wgeo.x
              cairo.move_to sgeo.x, sgeo.y
              cairo.line_to wgeo.x, wgeo.y
              cairo.line_to wgeo.x, wgeo.bottom
              cairo.line_to sgeo.x, sgeo.bottom
              cairo.close_path
              cairo.fill
            end
            # right
            if wgeo.right < sgeo.right && drect.right >= wgeo.right
              cairo.move_to wgeo.right, wgeo.y
              cairo.line_to sgeo.right, sgeo.y
              cairo.line_to sgeo.right, sgeo.bottom
              cairo.line_to wgeo.right, wgeo.bottom
              cairo.close_path
              cairo.fill
            end
            # top
            if wgeo.y > 0 && drect.y <= wgeo.y
              cairo.move_to sgeo.x, sgeo.y
              cairo.line_to sgeo.right, sgeo.y
              cairo.line_to wgeo.right, wgeo.y
              cairo.line_to wgeo.x, wgeo.y
              cairo.close_path
              cairo.fill
            end
            # bottom
            if wgeo.bottom < sgeo.bottom && drect.bottom >= wgeo.bottom
              cairo.move_to wgeo.x, wgeo.bottom
              cairo.line_to wgeo.right, wgeo.bottom
              cairo.line_to sgeo.right, sgeo.bottom
              cairo.line_to sgeo.x, sgeo.bottom
              cairo.close_path
              cairo.fill
            end

            # title bar
            return unless title_bar?(states)

            cairo.rectangle wgeo.x, wgeo.y, wgeo.width, TITLEBAR_HEIGHT
            if @active
              cairo.set_source_rgb(0.7, 0.7, 0.7)
            else
              cairo.set_source_rgb(0.5, 0.5, 0.5)
            end
            cairo.fill

            ## text (TODO)

            ## buttons
            cairo.line_width = 3
            cairo.set_source_rgb(0.2, 0.2, 0.2)

            icon_ratio = 0.65
            box = box_rect wgeo, :close, states
            ibox = box.dup
            ibox.inset_by TITLEBAR_HEIGHT * (1 - icon_ratio)

            ### close
            if @area == :close
              cairo.save do
                cairo.rectangle *box
                cairo.set_source_rgba 1.0, 0.0, 0.0, 0.4
                cairo.operator = Cairo::Operator::OVER
                cairo.fill
              end
            end
            cairo.move_to ibox.x,     ibox.y
            cairo.line_to ibox.right, ibox.bottom
            cairo.move_to ibox.right, ibox.y
            cairo.line_to ibox.x,     ibox.bottom
            cairo.stroke

            ### maximize
            ibox.offset_by -TITLEBAR_HEIGHT, 0
            box.offset_by -TITLEBAR_HEIGHT, 0
            if @area == :maximize
              cairo.save do
                cairo.rectangle *box
                cairo.set_source_rgba 0.0, 1.0, 0.0, 0.4
                cairo.operator = Cairo::Operator::OVER
                cairo.fill
              end
            end
            if states & STATE_MAXIMIZED == 0
              cairo.rectangle *ibox
            else
              sw = ibox.width / 2
              sh = ibox.height / 2
              cairo.rectangle ibox.x + sw / 2, ibox.y + sh / 2, sw, sh
            end
            cairo.stroke

            ### minimize
            ibox.offset_by -TITLEBAR_HEIGHT, 0
            box.offset_by -TITLEBAR_HEIGHT, 0
            if @area == :minimize
              cairo.save do
                cairo.rectangle *box
                cairo.set_source_rgba 0.0, 0.0, 1.0, 0.4
                cairo.operator = Cairo::Operator::OVER
                cairo.fill
              end
            end
            cairo.move_to ibox.x, ibox.bottom
            cairo.line_to ibox.right, ibox.bottom
            cairo.stroke
          end
        end

        HIT_TEST = [:top_left,    :top,    :top_right,
                    :left,        :client, :right,
                    :bottom_left, :bottom, :bottom_right].freeze

        def hit_test(x, y, window_geometry, states)
          ans = HIT_TEST[window_geometry.hit_test(x, y)]
          if ans == :client && title_bar?(states) && y < window_geometry.y + TITLEBAR_HEIGHT
            if x >= window_geometry.right - TITLEBAR_HEIGHT
              ans = :close
            elsif x >= window_geometry.right - TITLEBAR_HEIGHT * 2
              ans = :maximize
            elsif x >= window_geometry.right - TITLEBAR_HEIGHT * 3
              ans = :minimize
            else
              ans = :title_bar
            end
          end
          ans
        end

        private def invalidate_box(area)
          wgeo   = @toplevel.window_geometry
          states = @toplevel.states
          box = box_rect wgeo, area, states
          @toplevel.invalidate *box if box
        end

        def pointer_enter(x, y)
        end

        def pointer_motion(time, x, y)
          @pointer_x = x
          @pointer_y = y
          case @button_pressed_area
          when :title_bar
            if (@button_pressed_x - x).abs > 4 || (@button_pressed_y - y).abs > 4
              @toplevel.move
              @button_pressed_area = nil
            end
          when :left, :right, :top, :bottom, :top_left, :top_right, :bottom_left, :bottom_right
            @toplevel.resize @button_pressed_area
            @button_pressed_area = nil
          else
            wgeo   = @toplevel.window_geometry
            states = @toplevel.states
            area = hit_test x, y, wgeo, states
            if @area != area
              invalidate_box @area
              invalidate_box area
            end
            @area = area
          end
        end

        def pointer_leave
          invalidate_box @area
          @area = nil
        end

        def pointer_button(time, button, state)
          if state == Wayland::Wl::Pointer[:button_state].pressed
            if @button_pressed_area.nil? ||
               button != @button ||
               (@pointer_x - @button_pressed_x).abs > 4 ||
               (@pointer_y - @button_pressed_y).abs > 4 ||
                 (time - @button_pressed_time) > 500
              @button_pressed_area = @area
              @button = button
              @button_pressed_x = @pointer_x
              @button_pressed_y = @pointer_y
              @button_pressed_time = time
              @button_pressed_count = 1
            else
              @button_pressed_count += 1
            end
          else
            if @button_pressed_area == @area && button == BTN_LEFT
              case @button_pressed_area
              when :title_bar
                if @button_pressed_count > 1 && (time - @button_pressed_time).abs < 500
                  @toplevel.toggle_maximized
                  @button_pressed_area = nil
                end
              when :close
              when :minimize
                @toplevel.set_minimized
                @button_pressed_area = nil
              when :maximize
                @toplevel.toggle_maximized
                @button_pressed_area = nil
              end
            end
          end
        end

        def activated(active)
          @active = active
          if title_bar?(@toplevel.states)
            wgeo = @toplevel.window_geometry
            @toplevel.invalidate wgeo.x, wgeo.y, wgeo.width, TITLEBAR_HEIGHT
          end
        end

        def resized
          @area = nil
        end
      end

      class ServerDecoration
      end

      def initialize(client, width, height)
        super
        @nonclient = ClientDecoration.new self
        @xdg_toplevel = @xdg_surface.get_toplevel as: [Private::XdgToplevel, self]
        commit_now
      end
      attr_reader :window_geometry

      def on_xdg_surface_configure(serial)
        @serial     = serial
        next_width  = @xdg_toplevel.width
        next_height = @xdg_toplevel.height
        next_states = @xdg_toplevel.states.inject(0){|r, i| r | (1 << i) }
        states_diff = @states ^ next_states
        @states = next_states
        resized = false
        if next_width == 0 || next_height == 0
          @window_geometry = @nonclient.initial_window_geometry @init_size.width,           @init_size.height,
                                                                @xdg_toplevel.bounds_width, @xdg_toplevel.bounds_height,
                                                                @states
          resized = true
        elsif @window_geometry.width  != next_width  ||
              @window_geometry.height != next_height ||
              (states_diff & STATES_RESIZED) > 0
          @window_geometry = @nonclient.adjust_window_geometry next_width,                 next_height,
                                                               @xdg_toplevel.bounds_width, @xdg_toplevel.bounds_height,
                                                               @states
          resized = true
        end
        if states_diff & STATE_ACTIVATED > 0
          activated = ((@states & STATE_ACTIVATED) > 0)
          @client.activated activated
          @nonclient.activated activated
        end
        if resized
          @client_geometry = @window_geometry.dup
          @nonclient.adjust_client_geometry @client_geometry, @window_geometry, @states
          @nonclient.adjust_surface_size self, @window_geometry, @states
          @xdg_surface.set_window_geometry @window_geometry.x,     @window_geometry.y,
                                           @window_geometry.width, @window_geometry.height
          realloc_buffer
          @client.resized
          @nonclient.resized
        end
        update
      end

      def hit_test(x, y)
        if @client_geometry.contain? x, y
          ans = @client.hit_test *convert_to_client(x, y)
        else
          ans = @nonclient.hit_test x, y, @window_geometry, @states
        end
        ans
      end

      def on_wl_pointer_enter(serial, x, y)
        @serial = serial
        @pointer_x = x
        @pointer_y = y
        # 1. change cursor
        ## TODO
        # 2. notify event
        @nonclient.pointer_enter x, y
        if @client_geometry.contain? x, y
          @pointer_enter_client = true
          cx, cy = convert_to_client x, y
          @client.pointer_enter cx, cy
        else
          @pointer_enter_client = false
        end
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_leave(serial)
        @serial = serial
        if @pointer_enter_client
          @client.pointer_leave
        end
        @nonclient.pointer_leave
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_button(serial, time, button, state)
        @serial = serial
        if state == Wayland::Wl::Pointer[:button_state].pressed
          if @current_pointer_handler.nil?
            @current_pointer_handler = @client_geometry.contain?(@pointer_x, @pointer_y) ? @client : @nonclient
            @pointer_button_press_count = 0
          end
          @pointer_button_press_count += 1
          @current_pointer_handler.pointer_button time, button, state
        elsif @current_pointer_handler
          @current_pointer_handler.pointer_button time, button, state
          @pointer_button_press_count -= 1
          @current_pointer_handler = nil if @pointer_button_press_count == 0
        end
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_motion(time, x, y)
        @pointer_x = x
        @pointer_y = y
        case @current_pointer_handler
        when @client
          cx, cy = convert_to_client x, y
          @current_pointer_handler.pointer_motion time, cx, cy
        when @nonclient
          @current_pointer_handler.pointer_motion time, x, y
        else
          prev_in_client = @in_client
          if @in_client = @client_geometry.contain?(x, y)
            cx, cy = convert_to_client x, y
            unless prev_in_client
              @nonclient.pointer_leave
              @client.pointer_enter cx, cy
            end
            @client.pointer_motion time, cx, cy
          else
            if prev_in_client            
              @client.pointer_leave
              @nonclient.pointer_enter x, y
            end
            @nonclient.pointer_motion time, x, y
          end
        end
        lasy_update
        commit_if_needed
      end

      def on_wl_pointer_axis(time, axis, value)
        if @client_geometry.contain? @pointer_x, @pointer_y
          @client.pointer_axis(time, axis, value)
        end
        lasy_update
        commit_if_needed
      end

      def set_minimized
        @xdg_toplevel.set_minimized
        @current_pointer_handler = nil
      end

      def set_maximized
        @xdg_toplevel.set_maximized
        @current_pointer_handler = nil
      end

      def unset_maximized
        @xdg_toplevel.unset_maximized
        @current_pointer_handler = nil
      end

      def toggle_maximized
        if @states & STATE_MAXIMIZED == 0
          set_maximized
        else
          unset_maximized
        end
      end

      def move
        seat = @display[:wl_seat]
        @xdg_toplevel.move seat, @serial
        @current_pointer_handler = nil
      end

      def resize(edge)
        seat = @display[:wl_seat]
        @xdg_toplevel.resize seat, @serial, Wayland::Xdg::Toplevel[:resize_edge][edge]
        @current_pointer_handler = nil
      end

      private def draw_nonclient(cairo)
        @nonclient.draw(cairo)
      end
    end
  end
end
