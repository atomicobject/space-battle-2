class Map
  def initialize(max_width=32, max_height=32)
    @max_width = max_width
    @max_height = max_height
    @map = Array.new(2*@max_width) { Array.new(2*@max_height) { nil } }
  end

  def update_tile(tile)
    # puts tile.inspect
    # puts tile['x']+@max_width
    # puts tile['y']+@max_height
    @map[tile['x']+@max_width][tile['y']+@max_height] = tile
  end

  def at(x,y)
    col = @map[x+@max_width]
    col[y+@max_height] if col
  end

  def pretty(units, time_remaining)
    return if $quiet
    unit_lookup = Hash.new { |hash, key| hash[key] = {} }
    units.values.each do |u|
      ux = u['x']+@max_width
      uy = u['y']+@max_height
      col = unit_lookup[ux]
      col[uy] = u
    end
    (33-units.size).times { puts }
    units.values.each do |u|
      puts "#{u['id']} #{u['type']} #{u['status']}"
    end
    puts("="*66)
    @map.transpose.each.with_index do |rows, i|
      STDOUT.write "|"
      rows.each.with_index do |v, j|
        if v.nil?
          STDOUT.write "?"
        elsif v['resources']
          STDOUT.write "$"
        elsif v['blocked']
          STDOUT.write "X"
        elsif !v['visible']
          STDOUT.write "."
        else
          if unit_lookup[j][i]
            STDOUT.write "^"
          else
            STDOUT.write " "
          end
        end
      end
      STDOUT.puts "|"
    end
    puts("="*66)
    all_units = units.values
    base = all_units.find{|u| u['type'] == 'base'}
    puts "TIME REMAINING: #{time_remaining}"
    puts "PLAYER RES: #{base['resource']}" if base
    puts "UNIT RES: #{((all_units-[base]).compact).map{|u|u['resource']}.compact.reduce(0, &:+)}"
  end
end

