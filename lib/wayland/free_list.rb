module Wayland
  class FreeList
    class Entry < Struct.new(:first, :count)
      def last
        self.first + self.count
      end

      def get
        value = self.first
        self.first += 1
        self.count -= 1
        value
      end

      def empty?
        self.count == 0
      end

      def inc
        self.count += 1
      end

      def inc_backward
        self.first =- 1
        inc
      end

      def add(n)
        self.count += n
      end
    end

    RECENT_FREE_MAX = 64

    def initialize(min = 0, max = 0xffffffff)
      raise ArgumentError if min >= max
      @min = min
      @max = max
      @list = [ Entry.new(min, max - min + 1) ]
      @recent_free_list = []
    end

    def free(value)
      raise ArgumentError if value < @min || value > @max
      if @recent_free_list.size >= RECENT_FREE_MAX
        (RECENT_FREE_MAX / 4).times do
          put @recent_free_list.pop
        end
      end
      @recent_free_list.push value
    end

    def put(value)
      i = @list.bsearch_index{|x| x.first >= value}
      unless i
        if @list.last&.last == value
          @list.last.inc
        else
          @list.push Entry.new(value, 1)
        end
        return
      end
      if i > 0 && @list[i - 1].last == value
        @list[i - 1].inc
        if @list[i - 1].last == @list[i].first
          @list[i - 1].add @list[i].count
          @list.delete_at i
        end
        return
      end
      if value + 1 == @list[i].first
        @list[i].inc_backward
      else
        @list.insert i, Entry.new(value, 1)
      end
    end
    private :put

    def get
      return @recent_free_list.pop unless @recent_free_list.empty?
      return nil if @list.empty?
      ent = @list.first
      value = ent.get
      @list.shift if ent.empty?
      value
    end
  end
end
