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
def attack_command(dx,dy,id)
  cmd = {
    command: "ATTACK",
    dx: dx,
    dy: dy,
    unit: id,
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
    @player_id ||= json['player']
    time_remaining = json['time'] || 300_000

    cmds = []
    cmd_msg = {commands: cmds, player_id: @player_id}

    tile_updates = json['tile_updates'] || []
    unit_updates = json['unit_updates'] || []
    unless tile_updates.empty? && unit_updates.empty?
      tile_updates.each do |tu|
        map.update_tile tu
      end

      map.pretty(units, time_remaining) unless $queit
    end

    unit_updates = {}
    (json['unit_updates'] || []).each do |uu|
      unit_updates[uu['id']] = uu
    end

    unit_ids = unit_updates.keys | units.keys
    base = units.values.find{|u| u['type'] == 'base'}
    if time_remaining > 200_000
      if base && base['resource'] >= COST_OF_TANK
        cmds << create_command(:tank)
      end
    end

    unit_ids.each do |id|
      had_outstanding_move = outstanding_unit_cmds[id] == :move

      if uu = unit_updates[id]
        if uu['status'] == 'dead'
          outstanding_unit_cmds.delete id
          next
        end
        units[id] =  uu
        if uu['status'] == 'moving'
          outstanding_unit_cmds.delete(id) if outstanding_unit_cmds[id] == :move
        elsif uu['status'] == 'idle'
          res_dir = resource_adjacent_to(map, base, uu)
          if res_dir && (!uu['resource'] || uu['resource'] == 0) && uu['type'] == 'worker'
            cmds << gather_command(res_dir, id)
          else
            cmds << move_command(outstanding_unit_cmds, id)
          end
        elsif uu['type'] != 'base'
          # TODO can this go away?
          cmds << move_command(outstanding_unit_cmds, id)
        end

        if uu['type'] == 'tank' && uu['can_attack']
          x = uu['x']
          y = uu['y']
          catch :found_target do
            ((x-2)..(x+2)).each do |tx|
              ((y-2)..(y+2)).each do |ty|

                next if tx == x || ty == y # don't shoot self
                tile = map.at(tx,ty)
                unless tile.nil? || tile['units'].nil? || tile['units'].empty?
                  # TODO search for biggest bang-for-buck target
                  non_dead = tile['units'].select{|tu|tu['status'] != 'dead'}
                  unless non_dead.empty?
                    # p non_dead.inspect
                    cmds << attack_command(tx-x,ty-y,id)
                    throw :found_target
                  end
                end
              end
            end
          end
        end

      elsif had_outstanding_move
        cmds << move_command(outstanding_unit_cmds, id)
      end
    end

    j = Oj.dump(cmd_msg, mode: :compat)
    # puts "====="
    # puts j
    server_connection.puts(j)# unless cmds.empty?

  end

  server_connection.close
end
