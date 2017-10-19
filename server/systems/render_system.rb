module ZOrder
  Terrain = 1
  Env = 20
  Units = 30
  HUD = 60
  HEALTH = 61
  POPUP = 62
  Debug = 100
end


class RenderSystem
  AO_RED = Gosu::Color.rgba(253, 79, 87, 255)
  AO_GREEN = Gosu::Color.rgba(22, 203, 196, 255)
  AO_BLACK = Gosu::Color.rgba(76, 72, 69, 255)
  PLAYER_COLORS = [ AO_RED, AO_GREEN ]
  GAME_OFFSET = (RtsWindow::FULL_DISPLAY_WIDTH - RtsWindow::GAME_WIDTH)/2

  def initialize
    @font_cache = {}
    @color_cache = {}
    @draw_count = 0
  end

  def get_cached_font(font:nil,size:)
    @font_cache[font] ||= {}
    opts = {}
    opts[:name] if font if font
    @font_cache[font][size] ||= Gosu::Font.new size, opts
  end

  def draw(target, entity_manager, res, game)
    map = res[:map]
    map_info = entity_manager.first(MapInfo).get(MapInfo)
    images = res[:images]
    tile_size = RtsGame::TILE_SIZE

    draw_rect(target, 0, 0, 0, RtsWindow::FULL_DISPLAY_WIDTH, RtsWindow::FULL_DISPLAY_HEIGHT, AO_BLACK)

    map_scale = RtsWindow::GAME_WIDTH / (64*map.width.to_f)

    score_x = 0
    score_y = 0
    med_font = get_cached_font size: 24
    small_font = get_cached_font size: 18

    entity_manager.each_entity Base, PlayerOwned, Position do |rec|
      base, player, pos = rec.components

      label = entity_manager.query(
        Q.must(PlayerOwned).with(id: player.id).
          must(Label).
          must(Named).with(name: "player-name")
        ).first.get(Label)

      player_color = PLAYER_COLORS[player.id]
      other_player_color = PLAYER_COLORS[player.id-1]
      draw_rect(target, score_x, 0, 1, GAME_OFFSET, 50, player_color)

      name_img = Gosu::Image.from_text(label.text, 30, align: :center, width: GAME_OFFSET)
      name_img.draw(score_x, score_y+10, ZOrder::HUD)

      score_text = base.resource.to_s
      score_img = Gosu::Image.from_text(score_text, 64, align: :center, width: GAME_OFFSET)
      score_img.draw(score_x, score_y+60, ZOrder::HUD)

      player_info = entity_manager.query(Q.must(PlayerOwned).with(id: player.id).must(PlayerInfo)).first.components.last

      stats_y = 160
      images[:worker_icon].draw(score_x+42, stats_y, ZOrder::HUD, 0.4, 0.4)
      med_font.draw("x#{player_info.worker_count}", score_x+87, stats_y, ZOrder::HUD)

      images[:scout_icon].draw(score_x+37, stats_y+42, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.scout_count}", score_x+87, stats_y+50, ZOrder::HUD)

      images[:tank_icon].draw(score_x+37, stats_y+95, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.tank_count}", score_x+87, stats_y+100, ZOrder::HUD)

      images[:kill_icon].draw(score_x+32, stats_y+140, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.kill_count}", score_x+87, stats_y+150, ZOrder::HUD)

      images[:rip_icon].draw(score_x+32, stats_y+190, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.death_count}", score_x+87, stats_y+200, ZOrder::HUD)

      images[:total_res_icon].draw(score_x+37, stats_y+240, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.total_resources}", score_x+87, stats_y+250, ZOrder::HUD)

      images[:bad_commands_icon].draw(score_x+37, stats_y+290, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.invalid_commands}", score_x+87, stats_y+300, ZOrder::HUD)

      images[:total_commands_icon].draw(score_x+37, stats_y+340, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.total_commands}", score_x+87, stats_y+350, ZOrder::HUD)

      images[:total_units_icon].draw(score_x+37, stats_y+390, ZOrder::HUD, 0.6, 0.6)
      med_font.draw("x#{player_info.total_units}", score_x+87, stats_y+400, ZOrder::HUD)

      score_x += GAME_OFFSET + RtsWindow::GAME_WIDTH
    end

    @hud_imgs ||= {}
    score_x = 0
    entity_manager.each_entity Base, PlayerOwned, Position do |rec|
      base, player, pos = rec.components
      player_color = PLAYER_COLORS[player.id]
      other_player_color = PLAYER_COLORS[player.id-1]

      @hud_imgs[player.id] ||= target.record(GAME_OFFSET, RtsWindow::FULL_DISPLAY_HEIGHT) do
        stats_y = 160
        seen_count = 0
        mini_size = 10
        mini_width = 32*mini_size
        mini_scale = mini_width / (10*map.width.to_f)
        mini_x = (score_x + 40) / mini_scale
        mini_y = (stats_y+500) / mini_scale

        mini_clear_color = Gosu::Color.rgb(0xAA, 0xAA, 0xAA)
        mini_fog_color = Gosu::Color::GRAY
        mini_blocked_color = Gosu::Color.rgb(0x60, 0x60, 0x60)
        mini_unknown_color = Gosu::Color::BLACK
        tile_info = entity_manager.query(Q.must(PlayerOwned).with(id: player.id).must(TileInfo)).first.components.last


        # TODO cache this somewhere else?
        unit_recs = entity_manager.query(
          Q.must(Unit).must(PlayerOwned).must(Position))

        my_units = Hash.new{|h,k| h[k] = {}}
        their_units = Hash.new{|h,k| h[k] = {}}
        unit_recs.each do |urec|
          u,p,unit_pos = urec.components
          if u.status != :dead
            if p.id == player.id
              my_units[unit_pos.tile_x][unit_pos.tile_y] ||= 0
              my_units[unit_pos.tile_x][unit_pos.tile_y] += 1
            else
              their_units[unit_pos.tile_x][unit_pos.tile_y] ||= 0
              their_units[unit_pos.tile_x][unit_pos.tile_y] += 1
            end
          end
        end

        target.scale mini_scale do
          map.width.times do |mx|
            map.height.times do |my|
              bg_color = nil
              color = nil
              if TileInfoHelper.seen_tile?(tile_info, mx, my)
                seen_count += 1
                if TileInfoHelper.can_see_tile?(tile_info, mx, my)
                  if MapInfoHelper.resource_at(map_info,mx,my)
                    color = Gosu::Color::GREEN
                  elsif MapInfoHelper.blocked?(map_info,mx,my)
                    color = mini_blocked_color
                  elsif my_units[mx][my]
                    bg_color = Gosu::Color::WHITE
                    color = Gosu::Color.rgba(player_color.red, player_color.green, player_color.blue, [80*my_units[mx][my], 255].min)
                  elsif their_units[mx][my]
                    bg_color = Gosu::Color::WHITE
                    color = Gosu::Color.rgba(other_player_color.red, other_player_color.green, other_player_color.blue, [80*their_units[mx][my], 255].min)
                  else
                    color = mini_clear_color
                  end
                else
                  if MapInfoHelper.blocked?(map_info,mx,my)
                    color = mini_blocked_color
                  else
                    color ||= mini_fog_color
                  end
                end
              else
                color = mini_unknown_color
              end
              draw_rect(target, mini_x + mx*mini_size, mini_y + my*mini_size, ZOrder::HUD, mini_size, mini_size, bg_color) if bg_color
              draw_rect(target, mini_x + mx*mini_size, mini_y + my*mini_size, ZOrder::HUD+1, mini_size, mini_size, color)
            end
          end
        end

        images[:map_icon].draw(score_x+37, stats_y+440, ZOrder::HUD, 0.6, 0.6)
        perc_map = (seen_count.to_f/(map.width*map.height)*100).floor
        med_font.draw("#{perc_map}%", score_x+87, stats_y+450, ZOrder::HUD)
      end
    end

    target.translate(GAME_OFFSET, 0) do 
      img = images[:bg_space]
      img.draw 0, 0, ZOrder::Terrain

      target.scale map_scale do
        sorted_by_y_x = Hash.new{|h,k|h[k]=Hash.new{|hh,kk|hh[kk]=[]}}
        map.width.times do |x|
          map.height.times do |y|
            t = map.at(x,y)
            base_x = x*tile_size
            base_y = y*tile_size

            img = images[t.image]
            img.draw base_x, base_y, ZOrder::Terrain, 0.5, 0.5 if img

            t.objects.each do |obj|
              obj_img = images[obj.image]
              if obj_img 
                sorted_by_y_x[base_y][base_x] << [obj_img, false, ZOrder::Env, 1, 1]
              end
            end
          end
        end

        entity_manager.each_entity Sprited, Position do |rec|
          sprited, pos = rec.components
          # images[sprited.image].draw pos.x, pos.y, pos.z
          img = images[sprited.image]
          if img
            offset = sprited.offset || vec(0,0)
            scale = (sprited.scale.nil? || sprited.scale == 0) ? 0.75 : sprited.scale
            x_scale = sprited.x_scale || scale
            y_scale = sprited.y_scale || scale
            sorted_by_y_x[pos.y+offset.y][pos.x+offset.x] << [img,pos.rotation,pos.z,x_scale, y_scale]
          else
            puts "could not find sprite image for: #{sprited.image}"
          end
        end

        entity_manager.each_entity Textured, Position do |rec|
          tex, pos = rec.components
          img = images[tex.image]
          if img
            w = Gosu::Color::WHITE
            img.draw_as_quad tex.x1, tex.y1, w, tex.x2, tex.y2, w, tex.x3, tex.y3, w, tex.x4, tex.y4, w, 19
          else
            puts "could not find texture image for: #{tex.image}"
          end
        end


        entity_manager.each_entity Decorated, Position do |rec|
          dec, pos = rec.components
          # images[sprited.image].draw pos.x, pos.y, pos.z
          sorted_by_y_x[pos.y+dec.offset.y][pos.x+dec.offset.x] << [images[dec.image],0,pos.z+1, dec.scale, dec.scale]
        end


        half_tile = RtsGame::TILE_SIZE/2
        sorted_by_y_x.keys.sort.each do |y|
          sorted_by_y_x[y].keys.sort.reverse.each do |x|
            sorted_by_y_x[y][x].each do |(img,rot,z,sprite_x_scale,sprite_y_scale)|
              rot ||= 0
              img.draw_rot x+half_tile, y+half_tile, z, rot, 0.5, 0.5, sprite_x_scale, sprite_y_scale
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

    @hud_imgs[0].draw(0,0,ZOrder::HUD) if @hud_imgs[0]
    @hud_imgs[1].draw(GAME_OFFSET + RtsWindow::GAME_WIDTH,0,ZOrder::HUD) if @hud_imgs[1]

    # this is too intensive atm to leave on every frame and 
    # _really_ only needs to be updated once per turn
    if @draw_count == 10
      @hud_imgs = {}
      @draw_count = 0
    end
    @draw_count += 1

    if game.game_over?
      winner_id = game.winner
      # require 'pry'
      # binding.pry
      ent = entity_manager.query(
        Q.must(PlayerOwned).with(id: winner_id).
          must(Label).
          must(Named).with(name: "player-name")
        ).first
      name = ent.get(Label).text

      w = 800
      h = 400
      x = (RtsWindow::FULL_DISPLAY_WIDTH-w)/2
      y = (RtsWindow::FULL_DISPLAY_HEIGHT-h)/2

      winner_img = Gosu::Image.from_text("WINNER!", 75, align: :center, width: w)
      name_img = Gosu::Image.from_text(name, 65, align: :center, width: w)

      score_text = entity_manager.query(
        Q.must(PlayerOwned).with(id: winner_id).
          must(Base)).first.get(Base).resource
      score_img = Gosu::Image.from_text(score_text.to_s, 95, align: :center, width: w)
      winner_color = PLAYER_COLORS[winner_id]
      alpha_winner_color = Gosu::Color.argb(200, winner_color.red, winner_color.green, winner_color.blue)
      draw_rect(target, x, y, ZOrder::POPUP, w, h, alpha_winner_color)
      draw_box(target, x, y, ZOrder::POPUP, w, h, Gosu::Color::WHITE)

      top_margin = 80
      winner_img.draw(x, y+top_margin, ZOrder::POPUP)
      name_img.draw(x,y+top_margin+85,ZOrder::POPUP)
      score_img.draw(x, y+top_margin+170, ZOrder::POPUP)

    elsif game.show_instructions?
      x = RtsWindow::FULL_DISPLAY_WIDTH
      y = RtsWindow::FULL_DISPLAY_HEIGHT/2
      instructions_img = Gosu::Image.from_text("Press any key", y/5, align: :center, width: x)
      instructions_img.draw(0, y, ZOrder::POPUP)
    end

  end

private
  def draw_rect(t, x, y, z, width, height, color)
    t.draw_quad(x, y, color, x+width, y, color, x, y+height, color, x+width, y+height, color, z)
  end

  def draw_box(t, x, y, z, width, height, color)
    t.draw_line x, y, color, x+width, y, color, z
    t.draw_line x+width, y, color, x+width, y+height, color, z
    t.draw_line x+width, y+height, color, x, y+height, color, z
    t.draw_line x, y+height, color, x, y, color, z
  end

  def format_time_string(ms)
    return "00:00" if ms <= 0
    seconds = ms/1000
    Time.at(seconds).strftime("%M:%S")
  end
end
