$: << File.dirname(__FILE__)
require "pango"
require "miw/wl"
require "miw/wl/toplevel"

class ToplevelWindow
  def initialize(width, height)
    @window = MiW::Wl::Toplevel.new(self, width, height)
    @text = File.read __FILE__
    @ty = 0
    @bpx = 0
    @bpy = 0
    @cursor = 0
  end

  def draw(context, rect)
    # background
    size = @window.client_size
    width = size.width
    height = size.height
    context.set_source_color [0.8, 0.8, 0.8, 1.0]
    context.rectangle 0, 0, width, height
    context.fill

    layout = context.create_pango_layout
    layout.font_description = "monospace 10"
    layout.text = @text

    if @cursor.nil?
      lx = @bpx
      ly = @bpy - @ty
      _, @cursor, _ = layout.xy_to_index lx * Pango::SCALE, ly * Pango::SCALE
    end

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
  end

  def hit_test(x, y)
    :client
  end

  def resized
  end

  def activated(active)
    @active = active
    invalidate
  end

  def pointer_enter(*_)
  end

  def pointer_leave(*_)
  end

  def pointer_motion(time, x, y)
    @px = x.to_i
    @py = y.to_i
  end

  def pointer_button(time, button, state)
    if state == 1
      @cursor = nil
      @bpx = @px
      @bpy = @py
      invalidate
    end
  end

  def pointer_axis(time, axis, value)
    if axis == 0
      @ty -= value * 2
      @bpy -= value * 2
    end
    invalidate
  end

  def line_head(index)
    answer = 0
    if index > 0
      h = @text.rindex("\n", index - 1)
      answer = h + 1 if h
    end
    answer
  end

  def next_line(index)
    n = @text.index("\n", index)
    (n ? n + 1 : nil)
  end

  def cursor_up
    return if @cursor <= 0
    @pd ||= 0
    lh0 = line_head @cursor
    return if lh0 == 0
    d = [@cursor - lh0, @pd].max
    lh1 = line_head lh0 - 1
    if lh1 + d < lh0
      @pd = d
      @cursor = lh1 + d
    else
      @pd = d
      @cursor = lh0 - 1
    end
  end

  def cursor_down
    @pd ||= 0
    lh1 = next_line @cursor
    if lh1
      lh2 = next_line(lh1) || @text.size
      lh0 = line_head @cursor
      d = [@cursor - lh0, @pd].max
      if lh1 + d < lh2
        @pd = 0
        @cursor = lh1 + d
      else
        @pd = d
        @cursor = lh2 - 1
      end
    end
  end

  def key_down(key)
    case key
    when 0x20..0x7e
      @text.insert @cursor, key.chr
      @cursor += 1
    when 0xff0d
      @text.insert @cursor, "\n"
      @cursor += 1
      @pd = 0
    when 0xff51  # LEFT
      @cursor -= 1 if @cursor > 0
      @pd = 0
    when 0xff52  # UP
      cursor_up
    when 0xff53  # RIGHT
      @cursor += 1 if @cursor < @text.size
      @pd = 0
    when 0xff54  # DOWN
      cursor_down
    else
      p [key.to_s(16)]
    end
    invalidate
    @window.lasy_update
    @window.commit_if_needed
  end

  def pulse
    return unless @key
    @key_repeat_timeout -= 1
    if @key_repeat_timeout == 0
      @key_repeat_timeout = 2
      key_down @key
    end
  end

  def keyboard_key(time, key, state)
    if state == 1
      key_down key
      @key = key
      @key_repeat_timeout = 10
    else
      @key = nil
    end
  end

  def invalidate
    size = @window.client_size
    @window.invalidate_client 0, 0, size.width, size.height
  end
end

if __FILE__ == $0
  Wayland::Protocol.load_yaml File.join(File.dirname(__FILE__), "xdg-decoration-unstable-v1.yaml")
  MiW::Wl.init
  toplevel_window = ToplevelWindow.new 640, 480
  MiW::Wl.main_loop
end
