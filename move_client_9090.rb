require 'socket'
require 'json'

server = TCPServer.new 9090

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

  def pretty
    33.times { puts }
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
        else
          STDOUT.write " "
        end
      end
      STDOUT.puts "|"
    end
    puts("="*66)
  end
end

# require 'server/lib/vec'
# DIR_VECS = {
#   'N' => vec(0,-1),
#   'S' => vec(0,1),
#   'W' => vec(-1,0),
#   'E' => vec(1,0),
# }

def move_command(outstanding_unit_cmds, id)
  outstanding_unit_cmds[id] = :move
  dir = ["N","S","E","W"].sample
  cmd = {
    command: "MOVE",
    unit: id,
    dir: dir
  }
  puts "move #{id} #{dir}"
  cmd
end

loop do
  client = server.accept    # Wait for a client to connect
  units = {}
  outstanding_unit_cmds = {}
  map = Map.new

	while msg = client.gets
    json = JSON.parse(msg)

    @player_id ||= json['player']

    cmds = []
    cmd_msg = {commands: cmds, player_id: @player_id}

    tile_updates = json['tile_updates']
    if tile_updates
      tile_updates.each do |tu|
        map.update_tile tu
      end

      map.pretty
    end

    unit_updates = {}
    (json['unit_updates'] || []).each do |uu|
      unit_updates[uu['id']] = uu
    end

    unit_ids = unit_updates.keys | units.keys
    unit_ids.each do |id|
      if uu = unit_updates[id]
        units[id] =  uu
        if uu['status'] == 'moving'
          outstanding_unit_cmds.delete(id) if outstanding_unit_cmds[id] == :move
        elsif uu['status'] == 'idle'
          cmds << move_command(outstanding_unit_cmds, id)
        end
      end
      if outstanding_unit_cmds[id] == :move
        cmds << move_command(outstanding_unit_cmds, id)
      end
    end

    client.puts(cmd_msg.to_json) unless cmds.empty?

  end

  client.close
end
