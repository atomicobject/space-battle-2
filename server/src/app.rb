require 'gosu'
require 'slop'
# require 'awesome_print'
require_relative './game'

class RtsWindow < Gosu::Window
  def initialize(**opts)
    super(1024,1024,fullscreen: false)
    @input_cacher = InputCacher.new
    @last_millis = Gosu::milliseconds.to_f

    @game = RtsGame.new **opts
    preload_assets! @game.resources
  end

  def needs_cursor?
    true
  end

  def update
    begin
      self.caption = "FPS: #{Gosu.fps} ENTS: #{@game.entity_manager.num_entities}"

      delta = relative_delta
      input = take_input_snapshot
      @game.update delta: delta, input: input

    rescue StandardError => ex
      puts ex.inspect
      puts ex.backtrace.inspect
      raise ex
    end
  end

  def draw
    @game.render_system.draw self, @game.entity_manager, @game.resources
  end

  def button_down(id)
    close if id == Gosu::KbEscape
    if @game.started?
      @input_cacher.button_down id
    else
      @game.start! 
    end
  end

  def button_up(id)
    @input_cacher.button_up id
  end
  private

  def preload_assets!(res)
    images = {}
    RtsGame::ASSETS.each do |name,file|
      images[name] ||= Gosu::Image.new(file, tileable: true)
    end
    puts "loaded images: #{images.keys}"

    # TODO add sounds and music here?
    res[:images] = images
  end

  def relative_delta
    total_millis = Gosu::milliseconds.to_f
    delta = total_millis
    delta -= @last_millis if total_millis > @last_millis
    @last_millis = total_millis
    delta = RtsGame::MAX_UPDATE_SIZE_IN_MILLIS if delta > RtsGame::MAX_UPDATE_SIZE_IN_MILLIS
    delta
  end

  def take_input_snapshot
    total_millis = Gosu::milliseconds.to_f

    mouse_pos = {x: mouse_x, y: mouse_y}
    input_snapshot = @input_cacher.snapshot @last_snapshot, total_millis, mouse_pos
    @last_snapshot = input_snapshot
    input_snapshot
  end
end

# if $0 == __FILE__

	opts = Slop.parse do |o|
		o.string '-p1', '--p1_host', 'player 1 host', default: 'localhost'
		o.integer '-p1p', '--p1_port', 'player 1 port', default: 9090
		o.string '-p2', '--p2_host', 'player 2 host'
		o.integer '-p2p', '--p2_port', 'player 2 port', default: 9090
		o.string '-m', '--map', 'map filename to play (tmx format)', default: 'map.tmx'
		o.bool '-q', '--quiet', 'suppress output (quiet mode)'
		o.bool '-l', '--log', 'log entire game'
		o.bool '-f', '--fast', 'advance to the next turn as soon as all clients have sent a message'
		o.bool '-nu', '--no_ui', 'No GUI; exit code is winning player'
		o.integer '-t', '--time', 'length of game in ms', default: RtsGame::GAME_LENGTH_IN_MS
    o.on '--help', 'print this help' do
      puts o
      exit
    end
	end

  Thread.abort_on_exception = true
  trap("SIGINT") { exit! }

  clients = [
    {host: opts[:p1_host], port: opts[:p1_port]},
  ]
  clients << {host: opts[:p2_host], port: opts[:p2_port]} if opts[:p2_host]

  if opts[:no_ui]
    class FakeInput < Hash
      attr_accessor :total_time
    end
    @game = RtsGame.new map: opts[:map], clients: clients, fast: opts[:fast], time: opts[:time]
    @game.start!
    until @game.game_over?
      @game.update delta: nil , input: nil
    end

    @game.scores.each do |id, score|
      puts "Player #{id}: #{score}"
    end
    winner = @game.winner
    puts "Player #{winner} wins!"
    exit winner

    # require 'pry'
    # binding.pry
    # puts "YAY"

  else
    $window = RtsWindow.new map: opts[:map], clients: clients, fast: opts[:fast], time: opts[:time]
    $window.show
  end
# end
