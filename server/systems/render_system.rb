module ZOrder
  Terrain = 1
  Env = 20
  Units = 30
  HUD = 60
  HEALTH = 61
  Debug = 100
end


class RenderSystem
  AO_RED = Gosu::Color.rgba(253, 79, 87, 255)
  AO_GREEN = Gosu::Color.rgba(22, 203, 196, 255)
  AO_BLACK = Gosu::Color.rgba(76, 72, 69, 255)

  def initialize
    @font_cache = {}
    @color_cache = {}
  end

  def get_cached_font(font:nil,size:)
    @font_cache[font] ||= {}
    opts = {} 
    opts[:name] if font if font
    @font_cache[font][size] ||= Gosu::Font.new size, opts
  end

  def draw(target, entity_manager, res)
    map = res[:map]
    images = res[:images]
    tile_size = RtsGame::TILE_SIZE

    draw_rect(target, 0, 0, 0, RtsWindow::FULL_DISPLAY_WIDTH, RtsWindow::FULL_DISPLAY_HEIGHT, AO_BLACK)

    game_offset = (RtsWindow::FULL_DISPLAY_WIDTH - RtsWindow::GAME_WIDTH)/2
    target.translate(game_offset, 0) do
      img = images[:bg_space]
      img.draw 0, 0, ZOrder::Terrain

      target.scale 0.5 do
        sorted_by_y_x = Hash.new{|h,k|h[k]=Hash.new{|hh,kk|hh[kk]=[]}}
        map.width.times do |x|
          map.height.times do |y|
            t = map.at(x,y)
            base_x = x*tile_size
            base_y = y*tile_size
            unless t.image == :dirt1 || t.image == :dirt2
              # img = images[t.image]
              img = images[:space_block]
              if img
                img.draw base_x, base_y, ZOrder::Terrain, 0.45, 0.45
              else
                puts "could not find tile image for: #{t.image}"
              end
            end

            t.objects.each do |obj|
              # images[obj.image].draw base_x, base_y, ZOrder::Env
              obj_img = images[obj.image]
              if obj_img
                sorted_by_y_x[base_y][base_x] << [obj_img, false, ZOrder::Env, 1]
              else
                puts "could not find object image for: #{obj.image}"
              end
            end
          end
        end

        entity_manager.each_entity Sprited, Position do |rec|
          sprited, pos = rec.components
          # images[sprited.image].draw pos.x, pos.y, pos.z
          img = images[sprited.image]
          if img
            offset = sprited.offset
            sorted_by_y_x[pos.y+offset.y][pos.x+offset.x] << [img,pos.rotation,pos.z,0.75]
          else
            puts "could not find sprite image for: #{sprited.image}"
          end
        end

        entity_manager.each_entity Decorated, Position do |rec|
          dec, pos = rec.components
          # images[sprited.image].draw pos.x, pos.y, pos.z
          sorted_by_y_x[pos.y+dec.offset.y][pos.x+dec.offset.x] << [images[dec.image],false,pos.z+1, dec.scale]
        end


        half_tile = RtsGame::TILE_SIZE/2
        sorted_by_y_x.keys.sort.each do |y|
          sorted_by_y_x[y].keys.sort.reverse.each do |x|
            sorted_by_y_x[y][x].each do |(img,rot,z,sprite_scale)|
              rot ||= 0
              # x_scale = sprite_scale * (flipped ? 1 : -1)
              img.draw_rot x+half_tile,y+half_tile,z,rot,0.5,0.5,sprite_scale,sprite_scale
            end
          end
        end

        entity_manager.each_entity Label, Position do |rec|
          label, pos = rec.components
          font = get_cached_font font: label.font, size: label.size
          font.draw(label.text, pos.x+20, pos.y+60, pos.z)
        end

        entity_manager.each_entity Attack, Position do |rec|
          attack, pos = rec.components
          font = get_cached_font size: 10
          if attack.current_cooldown > 0
            font.draw(attack.current_cooldown, pos.x+20, pos.y-50, ZOrder::HUD)
          end
        end

        entity_manager.each_entity Health, Position do |rec|
          h, pos = rec.components
          x = pos.x
          y = pos.y
          bg_c = Gosu::Color.rgba(255,255,255,128)
          hp_c = Gosu::Color.rgba(20,255,20,128)
          if h.points < h.max && h.points > 0
            draw_rect(target, x, y-10, ZOrder::HEALTH, 60, 10, bg_c)
            draw_rect(target, x+1, y-9, ZOrder::HEALTH, 58*(h.points.to_f/h.max), 8, hp_c)
          end
        end


        # TODO figure out a clean way to do this as a Label, Position combo
        timer = entity_manager.first(Timer)
        if timer
          time_remaining = timer.get(Timer).ttl
          font = get_cached_font size: 48
          font.draw(format_time_string(time_remaining), map.width/2*tile_size-100, 50, ZOrder::HUD)
        end
      end
    end

    score_x = 0
    score_y = 30
    big_font = get_cached_font size: 64
    med_font = get_cached_font size: 24
    small_font = get_cached_font size: 18

    player_colors = [ AO_RED, AO_GREEN ]
    entity_manager.each_entity Base, PlayerOwned, Label do |rec|
      base, player, label = rec.components

      draw_rect(target, score_x, 0, 1, game_offset, 25, player_colors[player.id])

      score_text = base.resource.to_s
      x = score_x+60-(score_text.size-1/2.0*40)
      big_font.draw(score_text, score_x+110, score_y, ZOrder::HUD)
      med_font.draw("#{label.text}", score_x+10, score_y+64+10, ZOrder::HUD)

      # TODO some sort of PlayerStats component?
      # worker_count = 12
      # scout_count = 12
      # tank_count = 12

      # kills = 0
      # deaths = 0
      # orders = 4000
      # bad_commands = 2

      # small_font.draw("workers: #{worker_count}", score_x, score_y+120, ZOrder::HUD)
      # small_font.draw("scouts: #{scout_count}", score_x, score_y+140, ZOrder::HUD)
      # small_font.draw("tanks: #{tank_count}", score_x, score_y+160, ZOrder::HUD)

      # small_font.draw("kills: #{kills}", score_x, score_y+260, ZOrder::HUD)
      # small_font.draw("deaths: #{deaths}", score_x, score_y+280, ZOrder::HUD)
      # small_font.draw("orders: #{orders}", score_x, score_y+300, ZOrder::HUD)
      # small_font.draw("bad commands: #{bad_commands}", score_x, score_y+320, ZOrder::HUD)

      score_x += game_offset + RtsWindow::GAME_WIDTH
    end

  end

private
  def draw_rect(t, x, y, z, width, height, color)
    t.draw_quad(x, y, color, x+width, y, color, x, y+height, color, x+width, y+height, color, z)
	end

  def format_time_string(ms)
    return "00:00" if ms <= 0
    seconds = ms/1000
    Time.at(seconds).strftime("%M:%S")
  end
end
