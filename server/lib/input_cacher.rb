require 'set'

class InputSnapshot
  attr_reader :mouse_pos, :total_time

  def initialize(previous_snapshot=nil, total_time=0, down_ids=Set.new, mouse_pos={})
    @total_time = total_time
    @mouse_pos = mouse_pos.freeze
    @previous_snapshot = previous_snapshot
    @down_ids = down_ids
    @data = {}
  end

  def down?(id)
    @down_ids && @down_ids.include?(id)
  end
  
  def up?(id)
    !@down_ids || !@down_ids.include?(id)
  end

  def pressed?(id)
    @down_ids && @down_ids.include?(id) && !@previous_snapshot.down?(id)
  end

  def released?(id)
    @down_ids && !@down_ids.include?(id) && @previous_snapshot && @previous_snapshot.down?(id)
  end

  def [](k)
    @data[k]
  end
  def []=(k,v)
    @data[k] = v
  end

end

class InputCacher
  attr_reader :down_ids

  def initialize
    @down_ids = Set.new
  end

  def button_down(id)
    @down_ids.add id
  end

  def button_up(id)
    @down_ids.delete id
  end

  def snapshot(previous_snapshot, total_time, mouse_info)
    InputSnapshot.new(previous_snapshot, total_time, @down_ids.dup, mouse_info).freeze
  end
end


