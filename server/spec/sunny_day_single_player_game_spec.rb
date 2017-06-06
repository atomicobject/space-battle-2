require 'rspec'
require 'thread'
require 'drb/drb'
require 'childprocess'

require_relative "../src/game"

describe 'sunny day' do
  after do
    begin
      @process.poll_for_exit(10) if @process
    rescue ChildProcess::TimeoutError
      @process.stop # tries increasingly harsher methods to kill the process.
    end
  end

  it 'progresses a single turn' do
    client = start_client
    sleep 1
    start_remote_game(client)
    sleep 1
    game = client.remote_game
    sleep 2
    game.start!
    sleep 2
    expect(client.messages_from_server.size).to eq(1)

    msg = JSON.parse(client.messages_from_server.pop)
    expect(msg['turn']).to eq(0)

    sleep 1
    client.tick_turn
    # sleep 1
    # client.tick_turn
    sleep 1
    # TODO pop w/ timeout
    expect(client.messages_from_server.size).to eq(1)

    msg = JSON.parse(client.messages_from_server.pop)
    expect(msg['turn']).to eq(1)
  end
end

class Client
  attr_accessor :remote_game, :port, :messages_from_server
  def initialize(port:)
    @port = port
    @messages_from_server = Queue.new
    @total_time = 0
  end

  def tick_turn
    turn_duration = 200
    @total_time += turn_duration
    input = InputSnapshot.new nil, turn_duration
    puts "calling update with #{turn_duration}"
    @remote_game.update delta: turn_duration, input: input
    # TODO do we need to push on the input Q instead of calling update?
  end
end

SERVER_URI="druby://localhost:8787"
def start_client(port=9191)
  Thread.abort_on_exception = true
  c = Client.new port: 9191
  server = TCPServer.new port

  Thread.new do
    Thread.new(server.accept) do |server_connection|
      puts "connecting to server over DRb..."
      DRb.start_service
      c.remote_game = DRbObject.new_with_uri(SERVER_URI)
      sleep 2
      puts c.remote_game.inspect
      while msg = server_connection.gets
        puts "GOT MESSAGE!"
        c.messages_from_server.push msg
      end
      # listening_thread = Thread.new do
      # end
    end
  end
  c
end

def start_remote_game(client)
  # TODO properly shut this down
  @process = ChildProcess.build *(%w(ruby ./src/app.rb -nu -p1 localhost -p1p) + [client.port.to_s] + %w(-drb 8787))
  @process.leader = true
  @process.io.stdout = File.open("test-log.txt", "w+")
  @process.start
  @process
end
