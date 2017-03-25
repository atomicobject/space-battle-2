require 'socket'
require 'json'

server = TCPServer.new 9090

loop do
  client = server.accept    # Wait for a client to connect
  units = {}

	while msg = client.gets
    json = JSON.parse(msg)

    @player_id ||= json['player']

    cmds = []
    cmd_msg = {commands: cmds, player_id: @player_id}

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

      puts cmd_msg
      client.puts(cmd_msg.to_json)
    end

  end

  client.close
end
