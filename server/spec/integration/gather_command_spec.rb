require 'rspec'
require_relative "../../lib/vec"
require_relative "../../lib/core_ext"
require_relative "../../lib/entity_manager"
require_relative "../../components/components"
require_relative "../../src/game"

class TestGame < RtsGame
  def start_sim_thread(initial_state, input_queue, output_queue)
    # ewww.. don't do this
  end
end
# eewwww .. bring in conject or some other DI framework?
class NetworkManager# < NetworkManager
  def add_messages(msgs)
    @messages = msgs
  end

  def pop_messages_with_timeout!(timeout = nil)
    # returned canned messages
    msgs = @messages
    @messages = nil
    msgs || []
  end

  def write(player_id, msg)
    puts "writing: #{player_id} #{msg}"
  end

  def connect(host, port)
    conn = "fake_connection_#{@connection_count}"
    @connections[@connection_count] = conn
    @connection_count += 1
  end
end

class TestMessage
  attr_accessor :connection_id, :data
  def initialize(connection_id, data)
    @connection_id = connection_id
    @data = data
  end
end

module Prefab
  def self.shuffle_bases(array)
    array
  end
end

describe "GATHER command" do
  let(:game) do
    logger = GameLogger::NOOP.new
    g = TestGame.new map: 'maps/tiny.json', clients: [ {name: "Test Player 1"} ], fast: false, time: 20_000, drb_port: nil, logger: logger
    g.start!
    g
  end

  it 'gathers / drops a resource' do
    player_id = 0
    workers = game.entity_manager.query(
      Q.must(Unit).
        with(type: :worker).
        must(PlayerOwned).
        with(id: player_id)
    )
    first_unit_ent = workers[0]
    second_unit_ent = workers[1]

    add_command move(player_id, first_unit_ent.id, 'W')
    5.times { run_turn }

    2.times do
      add_command move(player_id, first_unit_ent.id, 'W')
      add_command move(player_id, second_unit_ent.id, 'W')
      5.times { run_turn }
    end
    see_unit_location(first_unit_ent.id, 1, 2)
    see_unit_location(second_unit_ent.id, 2, 2)

    add_command gather(player_id, first_unit_ent.id, 'N')
    run_turn
    see_unit_resources(first_unit_ent.id, 10)
    see_resource(1, 1, 10, 190)

    add_command drop(player_id, first_unit_ent.id, 'E', 20)
    run_turn
    see_no_resource(2, 2)

    add_command drop(player_id, first_unit_ent.id, 'S', 20)
    run_turn
    see_resource(1, 3, 10, 10)

    add_command gather(player_id, first_unit_ent.id, 'S')
    run_turn
    see_no_resource(1, 3)
    see_unit_resources(first_unit_ent.id, 10)
  end

  it 'handles race condition with movement' do
    player_id = 0
    workers = game.entity_manager.query(
      Q.must(Unit).
        with(type: :worker).
        must(PlayerOwned).
        with(id: player_id)
    )
    first_unit_ent = workers[0]
    second_unit_ent = workers[1]

    add_command move(player_id, second_unit_ent.id, 'W')

    3.times do
      add_command move(player_id, first_unit_ent.id, 'W')
      add_command move(player_id, first_unit_ent.id, 'W')
      5.times { run_turn }
    end
    see_unit_location(first_unit_ent.id, 1, 2)
    see_unit_location(second_unit_ent.id, 3, 2)

    add_command gather(player_id, first_unit_ent.id, 'N')
    run_turn
    see_unit_resources(first_unit_ent.id, 10)
    see_resource(1, 1, 10, 190)

    add_command move(player_id, second_unit_ent.id, 'W')
    4.times { run_turn }

    # should fail, because unit will be there
    add_command drop(player_id, first_unit_ent.id, 'E', 20)
    run_turn
    see_unit_location(second_unit_ent.id, 2, 2)
    see_no_resource(2, 2)
  end

  it 'safely empties a resource' do
    player_id = 0
    workers = game.entity_manager.query(
      Q.must(Unit).
        with(type: :worker).
        must(PlayerOwned).
        with(id: player_id)
    )
    expect(workers.size).to eq(6)
    first_unit_ent = workers[0]
    second_unit_ent = workers[1]

    # 200 / 20 = 10
    3.times do
      workers.each do |w|
        add_command move(player_id, w.id, 'W')
      end
      5.times { run_turn }
    end

    # should be 6 workers
    workers.each do |w|
      add_command gather(player_id, w.id, 'N')
    end
    run_turn
    workers.each do |w|
      add_command drop(player_id, w.id, 'S', 10)
    end
    run_turn
    see_resource(1, 1, 10, 200-60)
    see_resource(1, 3, 10, 60)


    workers.each do |w|
      add_command gather(player_id, w.id, 'N')
    end
    run_turn
    workers.each do |w|
      add_command drop(player_id, w.id, 'S', 10)
    end
    run_turn
    see_resource(1, 1, 10, 200-120)
    see_resource(1, 3, 10, 120)


    workers.each do |w|
      add_command gather(player_id, w.id, 'N')
    end
    run_turn
    workers.each do |w|
      add_command drop(player_id, w.id, 'S', 10)
    end
    run_turn
    see_resource(1, 1, 10, 200-180)
    see_resource(1, 3, 10, 180)

    workers.each do |w|
      add_command gather(player_id, w.id, 'N')
    end
    run_turn
    workers.each do |w|
      add_command drop(player_id, w.id, 'S', 10)
    end
    run_turn

    workers.each do |w|
      see_unit_resources(w.id, 0)
    end
    see_resource(1, 3, 10, 200)
    see_no_resource(1, 1)
  end

  describe 'two player game' do
    let(:game) do
      logger = GameLogger::NOOP.new
      g = TestGame.new map: 'maps/tiny.json', clients: [ {name: "Test Player 1"}, { name: "Test Player 2"} ], fast: false, time: 20_000, drb_port: nil, logger: logger
      g.start!
      g
    end

    it 'picks up and immediately collects resources when gathering from base' do
      base = game.entity_manager.query(Q.must(Unit).with(type: :base).must(Position).with(tile_x: 4, tile_y: 2))[0]
      player_id = 0

      workers = game.entity_manager.query(
        Q.must(Unit).
          with(type: :worker).
          must(PlayerOwned).
          with(id: player_id)
      )
      first_unit_ent = workers[0]

      base_unit_ent = game.entity_manager.query(
        Q.must(Unit).
          with(type: :base).
          must(PlayerOwned).
          with(id: player_id)
      )[0]

      # sanity checks
      see_unit_location(first_unit_ent.id, 4, 2)  # base location
      see_base_resources(base_unit_ent.id, 750) # initial base resources

      3.times do
        add_command move(player_id, first_unit_ent.id, 'W')
        5.times { run_turn }
      end
      see_unit_location(first_unit_ent.id, 1, 2)

      add_command gather(player_id, first_unit_ent.id, 'N')
      run_turn
      see_unit_resources(first_unit_ent.id, 10)

      add_command move(player_id, first_unit_ent.id, 'E')
      5.times { run_turn }
      see_unit_location(first_unit_ent.id, 2, 2)

      add_command drop(player_id, first_unit_ent.id, 'E', 10)
      run_turn
      see_resource(3, 2, 10, 10)

      # Move back to the base, but have to go around the resource
      add_command move(player_id, first_unit_ent.id, 'S')
      5.times { run_turn }

      2.times do
        add_command move(player_id, first_unit_ent.id, 'E')
        5.times { run_turn }
      end

      add_command move(player_id, first_unit_ent.id, 'N')
      5.times { run_turn }

      # Back at the base
      see_unit_location(first_unit_ent.id, 4, 2)

      # Gather the dropped resource
      add_command gather(player_id, first_unit_ent.id, 'W')
      run_turn

      # The base should have the resource, not the unit
      see_unit_resources(first_unit_ent.id, 0)
      see_no_resource(3, 2)
      see_base_resources(base_unit_ent.id, 760)
    end
  end


  # HELPERS
  def see_unit_location(id, x, y)
    pos = game.entity_manager.find_by_id(id).get(Position)
    expect(pos.tile_x).to eq(x)
    expect(pos.tile_y).to eq(y)
  end
  def see_unit_resources(id, amount)
    res_car = game.entity_manager.find_by_id(id).get(ResourceCarrier)
    expect(res_car.resource).to eq(amount)
  end

  def see_base_resources(id, amount)
    base = game.entity_manager.find_by_id(id).get(Base)
    expect(base.resource).to eq(amount)
  end

  def see_no_resource(x, y)
    map_info = game.entity_manager.first(MapInfo).get(MapInfo)
    res = MapInfoHelper.resource_at(map_info, x, y)
    expect(res).to be_nil
    game.entity_manager.each_entity(Resource, Position) do |ent|
      pos = ent.get(Position)
      expect([pos.x,pos.y]).not_to eq([x,y])
    end
  end

  def see_resource(x,y,value,total)
    map_info = game.entity_manager.first(MapInfo).get(MapInfo)
    res = MapInfoHelper.resource_at(map_info, x, y)
    expect(res).not_to be_nil
    res = game.entity_manager.find_by_id(res[:id]).get(Resource)
    expect(res.total).to eq(total)
    expect(res.value).to eq(value)
  end

  def add_command(cmd)
    @messages ||= []
    @messages << cmd
  end

  def run_turn
    turn = RtsGame::TURN_DURATION
    input = InputSnapshot.new
    input[:messages] = @messages || []
    game.world.update game.entity_manager, turn, input, nil
    @messages = []
  end

  def move(pid, uid, dir)
    TestMessage.new pid, {'commands' => [{'command' => 'MOVE',
      'unit' => uid,
      'dir' => dir.to_s}]}
  end
  def gather(pid, uid, dir)
    TestMessage.new pid, {'commands' => [{'command' => 'GATHER',
      'unit' => uid,
      'dir' => dir.to_s}]}
  end
  def drop(pid, uid, dir, value)
    TestMessage.new pid, {'commands' => [{'command' => 'DROP',
      'unit' => uid,
      'value' => value,
      'dir' => dir.to_s}]}
  end
end