require 'socket'
require 'thread'
require 'json'

class Game
  def process_updates_from_server(msgs)
    # msgs is an array of updates from the server
    # ...
    # return commands for your units
    {commands: []}
  end
end

if $0 == __FILE__
  server = TCPServer.new port
  Thread.abort_on_exception = true
  loop do
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
