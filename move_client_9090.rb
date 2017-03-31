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
    puts tile.inspect
    puts tile['x']+@max_width
    puts tile['y']+@max_height
    @map[tile['x']+@max_width][tile['y']+@max_height] = tile
  end

  def pretty
    33.times { puts }
    puts("="*66)
    @map.transpose.each.with_index do |rows, i|
      STDOUT.write "|"
      rows.each.with_index do |v, j|
        if i == 32 && j == 32
          STDOUT.write "H"
        elsif v.nil?
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


loop do
  client = server.accept    # Wait for a client to connect
  units = {}
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

    unit_updates = json['unit_updates']
    if unit_updates
      unit_updates.each do |uu|
        id = uu['id']
        units[id] =  uu
        if uu['status'] == 'idle'
          cmd = {
            command: "MOVE",
            unit: id,
            dir: ["N","S","E","W"].sample
          }
          cmds << cmd
        end
      end

      # puts cmd_msg
      client.puts(cmd_msg.to_json)
    end

  end

  client.close
end
