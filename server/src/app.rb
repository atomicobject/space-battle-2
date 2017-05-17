require 'gosu'
require 'slop'
# require 'awesome_print'
require_relative './game'

class RtsWindow < Gosu::Window
  def initialize(clients:,map:)
    super(1024,1024,false)
    @input_cacher = InputCacher.new
    @last_millis = Gosu::milliseconds.to_f

    @game = RtsGame.new clients: clients, map: map
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

    rescue Exception => ex
      puts ex.inspect
      puts ex.backtrace.inspect
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

if $0 == __FILE__

	opts = Slop.parse do |o|
		o.string '-p1', '--p1_host', 'player 1 host', default: 'localhost'
		o.integer '-p1p', '--p1_port', 'player 1 port', default: 9090
		o.string '-p2', '--p2_host', 'player 2 host'
		o.integer '-p2p', '--p2_port', 'player 2 port', default: 9090
		o.string '-m', '--map', 'map filename to play (tmx format)', default: 'map.tmx'
		o.bool '-q', '--quiet', 'suppress output (quiet mode)'
		o.bool '-l', '--log', 'log entire game'
    o.on '--help', 'print this help' do
      puts o
      exit
    end
	end

  Thread.abort_on_exception = true
  clients = [
    {host: opts[:p1_host], port: opts[:p1_port]},
  ]
  clients << {host: opts[:p2_host], port: opts[:p2_port]} if opts[:p2_host]

  $window = RtsWindow.new map: opts[:map], clients: clients 
  $window.show
end
