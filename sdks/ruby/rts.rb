require 'socket'
require 'thread'
require 'json'
require 'set'

class Game
  MOVE_DIRECTIONS = ['N', 'S', 'W', 'E']
  MOVE_COMMAND = 'MOVE'
  def process_updates_from_server(msgs)
    # msgs is an array of updates from the server
    @units ||= Set.new
    msgs.each do |msg|
      msg['unit_updates'].each do |uu|
        @units << uu['id'] if uu['type'] != 'base'
      end
    end
    # ...
    # return commands for your units
    {commands: [
      {command: MOVE_COMMAND, unit: @units.to_a.sample, dir: MOVE_DIRECTIONS.sample},
    ]}
  end
end

if $0 == __FILE__
  port = ARGV[0] || 9090
  server = TCPServer.new port
  Thread.abort_on_exception = true
  loop do
    puts "waiting for connection on #{port}"
    Thread.new(server.accept) do |server_connection|
      game = Game.new
      msg_from_server = Queue.new

      listening_thread = Thread.new do
        begin
          while msg = server_connection.gets
            msg_from_server.push JSON.parse(msg)
          end
        end
      end

      loop do
        msg = msg_from_server.pop
        msgs = [msg]
        until msg_from_server.empty?
          puts "!!! missed turn!"
          msgs << msg_from_server.pop 
        end

        commands = game.process_updates_from_server(msgs)
        server_connection.puts(commands.to_json)
      end

      server_connection.close
    end
  end
end
