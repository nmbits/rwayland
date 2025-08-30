$: << File.dirname(__FILE__)

require 'rwaylandtk'
require 'pango'
require 'logger'

class MyApplicationWindow < RWaylandTk::ToplevelWindow

  TITLE_BAR_SIZE = 20
  RESIZER_SIZE = 20

  def initialize(width, height)
    super
    set_title("Example Window", "Example App")
    @text = File.read __FILE__
    @ty = TITLE_BAR_SIZE
    @cursor = 0
  end

  def mouse_moved(x, y)
    @px = x
    @py = y
  end

  def mouse_down(button, time, serial)
    return unless @py
    seat = @display[:wl_seat]
    if @py < TITLE_BAR_SIZE
      @xdg_toplevel.move(seat, serial)
    elsif @px > width - RESIZER_SIZE && @py > height - RESIZER_SIZE
      @xdg_toplevel.resize(seat, serial, Wayland::Xdg::Toplevel[:resize_edge].bottom_right)
    else
      lx = @px
      ly = @py - @ty
      ans = content_pango_layout.xy_to_index lx * Pango::SCALE, ly * Pango::SCALE
      inside, index, trailing = ans
      index
      @cursor = index
      invalidate
    end
  end

  def axis(time, axis, value)
    if axis == 0
      @ty -= value * 2
    end
    invalidate
  end

  def content_pango_layout
    context = cairo_context
    if context && !@pango_layout
      @pango_layout = context.create_pango_layout
      @pango_layout.font_description = "monospace 10"
    end
    @pango_layout
  end
  
  def title_bar_pango_layout
    context = cairo_context
    if context && !@title_bar_pango_layout
      @title_bar_pango_layout = context.create_pango_layout
      @title_bar_pango_layout.font_description = "monospace 10"
      @title_bar_pango_layout.text = title
    end
    @title_bar_pango_layout
  end

  def cursor_up
    if @cursor > 0
      @pd ||= 0
      rn0 = @text.rindex("\n", @cursor - 1) || 0
      if rn0 > 0
        d = [@cursor - rn0, @pd].max
        rn1 = @text.rindex("\n", rn0 - 1) || 0
        if rn1 + d < rn0
          @pd = 0
          @cursor = rn1 + d
        else
          @pd = d
          @cursor = rn0
        end
        invalidate
      end
    end
  end

  def cursor_down
    @pd ||= 0
    rn0 = @text.rindex("\n", @cursor - 1) || 0
    d = [@cursor - rn0, @pd].max
    rn1 = @text.index("\n", @cursor)
    if rn1
      rn2 = @text.index("\n", rn1 + 1) || @text.size
      if rn1 + d < rn2
        @pd = 0
        @cursor = rn1 + d
      else
        @pd = d
        @cursor = rn2
      end
    end
  end

  def key_down(key)
    case key
    when 0x20..0x7e
      @text.insert @cursor, key.chr
      @cursor += 1
    when 0xff51  # LEFT
      @cursor -= 1 if @cursor > 0
    when 0xff52  # UP
      cursor_up
    when 0xff53  # RIGHT
      @cursor += 1 if @cursor < @text.size
    when 0xff54  # DOWN
      cursor_down
    else
      p [key.to_s(16)]
    end
  end

  def draw
    context = cairo_context
    context.save do
      # background
      context.set_source_color [0.8, 0.8, 0.8, 1.0]
      context.rectangle 0, 0, width, height
      context.fill

      layout = content_pango_layout
      layout.text = @text

      # Cursor
      pos = layout.index_to_pos(@cursor)
      context.set_source_color [0, 0.9, 0, 1]
      w = pos.width > 0 ? pos.width / Pango::SCALE : 10
      h = pos.height > 0 ? pos.height / Pango::SCALE : 10
      context.rectangle pos.x / Pango::SCALE, pos.y / Pango::SCALE + @ty, w, h
      context.fill

      # Text
      context.move_to 0, @ty
      context.set_source_color [0.2, 0.3, 0.2, 1]
      context.show_pango_layout layout

      # title bar
      title_bar_layout = title_bar_pango_layout
      tw, th = title_bar_layout.pixel_size
      tx = (width - tw) / 2
      ty = (TITLE_BAR_SIZE - th) / 2
      context.set_source_color [0, 0, 0, 0.5]
      context.rectangle 0, 0, width, TITLE_BAR_SIZE
      context.fill
      context.move_to tx, ty
      context.set_source_color [0.9, 0.9, 0.9, 1]
      context.show_pango_layout title_bar_layout

      # resizer
      context.set_source_color [0, 0, 0, 0.5]
      context.rectangle width - RESIZER_SIZE, height - RESIZER_SIZE, RESIZER_SIZE, RESIZER_SIZE
      context.fill
    end
  end
end

if __FILE__ == $0
  RWaylandTk.init
  w = MyApplicationWindow.new(640, 480).show
  RWaylandTk.main_loop
end
