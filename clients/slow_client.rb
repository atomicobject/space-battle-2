require 'socket'
require 'json'
require 'oj'
require_relative '../server/lib/vec'
require_relative './client_map'

port = ARGV.size > 0 ? ARGV[0].to_i : 9090
$quiet = ARGV.size > 1

if $quiet
  def puts(*args)
  end
end
server = TCPServer.new port

DIR_VECS = {
  'N' => vec(0,-1),
  'S' => vec(0,1),
  'W' => vec(-1,0),
  'E' => vec(1,0),
}
COST_OF_WORKER = 100
COST_OF_SCOUT = 130
COST_OF_TANK = 150

def resource_adjacent_to(map, base, unit_info)
  x = unit_info['x']
  y = unit_info['y']

  tile = map.at(x,y)
  if tile
    DIR_VECS.each do |dir, dir_vec|
      xx = x + dir_vec.x
      yy = y + dir_vec.y

      unless base.nil? || (base['x'] == xx && base['y'] == yy)
        tile = map.at(xx,yy)
        # XXX will this allow stealing from other player's bases?
        return dir if tile && tile['resources']
      end
    end
  end
  nil
end

def gather_command(dir, id)
  cmd = {
    command: "GATHER",
    unit: id,
    dir: dir
  }
end

def create_command(type)
  cmd = {
    command: "CREATE",
    type: type
  }
end

def move_command(outstanding_unit_cmds, id)
  outstanding_unit_cmds[id] = :move
  dir = ["N","S","E","W"].sample
  cmd = {
    command: "MOVE",
    unit: id,
    dir: dir
  }
end

loop do
  server_connection = server.accept    # Wait for a server_connection to connect
  puts "CONNECTED"
  units = {}
  outstanding_unit_cmds = {}
  map = Map.new

	while msg = server_connection.gets
    json = JSON.parse(msg)
    cmds = []
    cmd_msg = {commands: cmds, player_id: @player_id}

    j = Oj.dump(cmd_msg, mode: :compat)
    # puts "====="
    # puts j
    sleep 1
    server_connection.puts(j)# unless cmds.empty?

  end

  server_connection.close
end
