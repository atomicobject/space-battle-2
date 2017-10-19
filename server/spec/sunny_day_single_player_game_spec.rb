require 'rspec'
require 'thread'
require 'drb/drb'
require 'childprocess'
require 'gosu'

require_relative "../src/game"

describe 'sunny day' do
  after do
    begin
      @process.poll_for_exit(4) if @process
    rescue ChildProcess::TimeoutError
      @process.stop # tries increasingly harsher methods to kill the process.
    end
  end

  it 'reports end of game results' do
    client = start_client
    sleep 1
    start_remote_game(client)
    sleep 1
    game = client.remote_game
    sleep 2
    expect(game).to be
    game.start!

    msg = client.messages_from_server.pop
    (300_000/200).times do
      client.tick_turn
      # sleep 0.01
      msg = JSON.parse(client.messages_from_server.pop)
      # puts msg['time']
    end
    expect(msg['time']).to eq(0)
    expect(msg['results']).to eq({
      '0' => {
        'score' => 750 #starting amount
      }
    })
    # msg = client.messages_from_server.pop
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
    game_info = msg['game_info']
    expect(game_info['map_width']).to eq(32)
    expect(game_info['map_height']).to eq(32)
    expect(game_info['turn_duration']).to eq(200)
    expect(game_info['game_duration']).to eq(300_000)
    expect(game_info['unit_info']).to eq(
      'base' => {
        'hp' => 300,
        'range' => 2,
      },
      'worker' => {
        'cost' => 100,
        'hp' => 10,
        'range' => 2,
        'speed' => 5,
        'attack_damage' => 2,
        'attack_type' => 'melee',
        'attack_cooldown_duration' => 30,
        'can_carry' => true,
        'create_time' => 50,
      },
      'scout' => {
        'cost' => 130,
        'hp' => 5,
        'range' => 5,
        'speed' => 3,
        'attack_damage' => 1,
        'attack_type' => 'melee',
        'attack_cooldown_duration' => 30,
        'create_time' => 100,
      },
      'tank' => {
        'cost' => 150,
        'hp' => 30,
        'range' => 2,
        'speed' => 10,
        'attack_damage' => 4,
        'attack_type' => 'ranged',
        'attack_cooldown_duration' => 70,
        'create_time' => 150,
      },
    )

    sleep 1
    client.tick_turn
    # sleep 1
    # client.tick_turn
    sleep 1
    # TODO pop w/ timeout
    expect(client.messages_from_server.size).to eq(1)

    msg = JSON.parse(client.messages_from_server.pop)
    expect(msg['turn']).to eq(1)
    expect(msg['game_info']).to be(nil)
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
