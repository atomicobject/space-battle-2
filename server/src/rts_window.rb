require 'gosu'
class RtsWindow < Gosu::Window
  FULL_DISPLAY_WIDTH = 1820
  FULL_DISPLAY_HEIGHT = 1024
  GAME_WIDTH = 1024

  ASSETS = {
    base0: 'assets/PNG/Retina/Other/base_red.png',
    worker0: 'assets/PNG/Retina/Other/worker_red.png',
    scout0: 'assets/PNG/Retina/Other/scout_red.png',
    tank0: 'assets/PNG/Retina/Other/tank_red.png',
    laser0: 'assets/PNG/Retina/Other/laser_red.png',
    base1: 'assets/PNG/Retina/Other/base_green.png',
    worker1: 'assets/PNG/Retina/Other/worker_green.png',
    scout1: 'assets/PNG/Retina/Other/scout_green.png',
    tank1: 'assets/PNG/Retina/Other/tank_green.png',
    laser1: 'assets/PNG/Retina/Other/laser_green.png',

    small_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_14.png',
    large_res1: 'assets/PNG/Retina/Environment/scifiEnvironment_15.png',
    explosion1: 'assets/PNG/Retina/Other/explosion1.png',
    explosion2: 'assets/PNG/Retina/Other/explosion2.png',
    explosion3: 'assets/PNG/Retina/Other/explosion3.png',
    explosion4: 'assets/PNG/Retina/Other/explosion4.png',
    melee1: 'assets/PNG/Retina/Other/melee1.png',
    melee2: 'assets/PNG/Retina/Other/melee2.png',
    melee3: 'assets/PNG/Retina/Other/melee3.png',
    melee4: 'assets/PNG/Retina/Other/melee4.png',

    ff_cap_down: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Down.png',
    ff_cap_left: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Left.png',
    ff_cap_right: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Right.png',
    ff_cap_up: 'assets/PNG/Retina/Other/Force-Field/FF-Cap/FF-Cap-Up.png',
    ff_corner_1: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-1.png',
    ff_corner_2: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-2.png',
    ff_corner_3: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-3.png',
    ff_corner_4: 'assets/PNG/Retina/Other/Force-Field/FF-Corner/FF-Corner-4.png',
    ff_cross: 'assets/PNG/Retina/Other/Force-Field/FF-Cross/FF-Cross-All.png',
    ff_single_horizontal: 'assets/PNG/Retina/Other/Force-Field/FF-Single/FF-Single-Horizontal.png',
    ff_single_vertical: 'assets/PNG/Retina/Other/Force-Field/FF-Single/FF-Single-Vertical.png',
    ff_horizontal: 'assets/PNG/Retina/Other/Force-Field/FF-Straight/FF-Straight-Horizontal.png',
    ff_vertical: 'assets/PNG/Retina/Other/Force-Field/FF-Straight/FF-Straight-Vertical.png',
    ff_t_down: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Down.png',
    ff_t_left: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Left.png',
    ff_t_right: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Right.png',
    ff_t_up: 'assets/PNG/Retina/Other/Force-Field/FF-T/FF-T-Up.png',

    bg_space: 'assets/PNG/Retina/Other/bg_space.jpg',
    space_block: 'assets/PNG/Retina/Other/test_space_block.png',

    tank_icon: 'assets/PNG/Retina/Other/tank_icon.png',
    scout_icon: 'assets/PNG/Retina/Other/scout_icon.png',
    worker_icon: 'assets/PNG/Retina/Other/worker_icon.png',
    kill_icon: 'assets/PNG/Retina/Other/kills_icon.png',
    rip_icon: 'assets/PNG/Retina/Other/deaths_icon.png',

    total_units_icon: 'assets/PNG/Retina/Other/total_units_icon.png',
    total_res_icon: 'assets/PNG/Retina/Other/resources_icon.png',
    bad_commands_icon: 'assets/PNG/Retina/Other/bad_commands_icon.png',
    total_commands_icon: 'assets/PNG/Retina/Other/total_commands_icon.png',
    map_icon: 'assets/PNG/Retina/Other/map_icon.png',

    explosion_sound1: 'assets/sounds/explosion1.wav',
    explosion_sound2: 'assets/sounds/explosion2.wav',
    melee_sound1: 'assets/sounds/melee1.wav',
    melee_sound2: 'assets/sounds/melee2.wav',
    harvest_sound1: 'assets/sounds/harvest1.wav',
    harvest_sound2: 'assets/sounds/harvest2.wav',
    collect_sound: 'assets/sounds/collect.wav',
    game_over_sound: 'assets/sounds/collect.wav',

    peace_music1: 'assets/music/peace1.mp3',
    peace_music2: 'assets/music/peace2.mp3',
    peace_music3: 'assets/music/peace3.mp3',
    battle_music1: 'assets/music/battle1.mp3',
  }


  def initialize(**opts)
    super(FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT, fullscreen: opts.delete(:fullscreen))
    @render_system = RenderSystem.new
    @input_cacher = InputCacher.new
    @last_millis = Gosu::milliseconds.to_f

    @game = RtsGame.new **opts
    preload_assets! @game.resources
    self.caption = "Atomic Games: RTS"
  end

  def needs_cursor?
    true
  end

  def update
    begin
      # self.caption = "FPS: #{Gosu.fps} ENTS: #{@game.entity_manager.num_entities}"
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
    # @game.render_mutex.synchronize do
      @render_system.draw self, @game.entity_manager, @game.resources, @game
    # end
  end

  def button_down(id)
    if id == Gosu::KbEscape
      close
    else
      if @game.started?
        if id == Gosu::KbP
          @game.pause!
        end
        @input_cacher.button_down id
      else
        @game.start!
      end
    end
    super
  end

  def button_up(id)
    @input_cacher.button_up id
  end
  private

  def preload_assets!(res)
    images = {}
    sounds = {}
    music = {}
    ASSETS.each do |name,file|
      if file.end_with? '.wav'
        sounds[name] ||= Gosu::Sample.new(file)
      elsif file.end_with? '.mp3'
        music[name] ||= Gosu::Song.new(file)
      else
        images[name] ||= Gosu::Image.new(file, retro: true, tileable: true)
      end
    end
    puts "loaded images: #{images.keys}"

    res[:images] = images
    res[:sounds] = sounds
    res[:music] = music
    nil
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

require_relative '../systems/render_system'
