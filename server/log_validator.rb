require 'json'
require 'pry'

log_name = ARGV[0]

if log_name.nil? || !File.exists?(log_name)
  puts "Missing log file!"
  exit 1
end

TILE_SIZE = 64

def verify_all_resources_turn_in(game_state)
  map_info = game_state['state'].find{|eid, ent|ent.keys.first == "MapInfo"}[1]
  bases = game_state['state'].select{|eid, ent| ent && ent.keys.include?("Base")}
  units = game_state['state'].select{|eid, ent| ent && ent.keys.include?("Unit")}

  units.each do |(id, ent)|
    # unit is next to its base, and still holding resources
    next if ent["Base"]
    next unless res_car = ent["ResourceCarrier"]

    pid = ent["PlayerOwned"]["id"]
    base_ent = bases.find{|(base_id, base_ent)| base_ent["PlayerOwned"]['id'] == pid}[1]

    if ent["Label"] && res_car["resource"].to_s != ent["Label"]["text"].to_i.to_s
      puts "Unit(#{id}) for player #{pid} had out of sync resource label"
    end

    if res_car["resource"] > 0
      x = ent["Position"]['x']
      y = ent["Position"]['y']
      bx = base_ent["Position"]['x']
      by = base_ent["Position"]['y']

      if (bx-x).abs <= TILE_SIZE && (by-y).abs <= TILE_SIZE
        puts "Unit(#{id}) for player #{pid} had resources at end of turn while standing next to base (x,y)"
      end

      tx = ent["Position"]['tile_x']
      ty = ent["Position"]['tile_y']
      btx = base_ent["Position"]['tile_x']
      bty = base_ent["Position"]['tile_y']

      if (btx-tx).abs <= 1 && (bty-ty).abs <= 1
        puts "Unit(#{id}) for player #{pid} had resources at end of turn while standing next to base (tile_x,tile_y)"
      end
    end
  end
end

def verify_moving_positions(game_state)
  map_info = game_state['state'].find{|eid, ent|ent.keys.first == "MapInfo"}[1]
  bases = game_state['state'].select{|eid, ent| ent && ent.keys.include?("Base")}
  units = game_state['state'].select{|eid, ent| ent && ent.keys.include?("Unit")}

  units.each do |(id, ent)|
    next if ent["Unit"]['status'] != 'moving'

    x = ent["Position"]['x']
    y = ent["Position"]['y']
    tx = ent["Position"]['tile_x']
    ty = ent["Position"]['tile_y']

    if (x - tx*TILE_SIZE).abs > TILE_SIZE || (y - ty*TILE_SIZE).abs > TILE_SIZE
      puts "Moving is out of sync!"
    end
  end
end

def verify_sent_messages_for_resource_turn_in(last_game_state, msg)
  player = msg['id']
  sent_msg = JSON.parse(msg["msg"])

  unit_updates = sent_msg['unit_updates']
  tile_updates = sent_msg['tile_updates']
  unit_updates.each do |uu|
    next if uu['type'] == 'base'
    res = uu['resource'] || 0
    if uu['x'].abs <= 1 && uu['y'].abs <= 1 && res > 0
      puts "Unit is next to base w/ resources!!"
    end
  end
end

def verify_single_command_per_unit(last_game_state, msg)
  player = msg['id']
  rec_msg = msg['msg']

  commands = rec_msg['commands']
  unit_cmds = commands.group_by{|cmd_hash| cmd_hash['unit']}
  turn = last_game_state['turn']
  unit_cmds.each do |uid, ucs|
    if ucs.size > 1
      puts "Multiple commands issued for a single unit #{uid} #{ucs.inspect}"
    end
  end
end

File.open log_name do |log_file|
  last_game_state = nil
  while raw = log_file.gets
    msg = JSON.parse(raw)
    if msg['type'] == 'game_state'
      last_game_state = msg
      verify_all_resources_turn_in(msg) 
      verify_moving_positions(msg)
    elsif msg['type'] == 'to_player'
      verify_sent_messages_for_resource_turn_in(last_game_state, msg)
    elsif msg['type'] == 'from_player'
      verify_single_command_per_unit(last_game_state, msg)
    end
  end
end

