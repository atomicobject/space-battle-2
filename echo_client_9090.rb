require 'socket'

server = TCPServer.new 9090

loop do
  client = server.accept    # Wait for a client to connect
	while msg = client.gets
    puts msg	
  end

  client.close
end
