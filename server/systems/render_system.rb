module ZOrder
  Terrain, Env, Units, HUD, Debug = *(0..100)
end


class RenderSystem

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
    target.scale 0.5 do
      map = res[:map]
      images = res[:images]
      tile_size = RtsGame::TILE_SIZE
      sorted_by_y_x = Hash.new{|h,k|h[k]=Hash.new{|hh,kk|hh[kk]=[]}}
      map.width.times do |x|
        map.height.times do |y|
          t = map.at(x,y)
          base_x = x*tile_size
          base_y = y*tile_size
          img = images[t.image]
          if img
            img.draw base_x, base_y, ZOrder::Terrain
          else
            puts "could not find tile image for: #{t.image}"
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
        sorted_by_y_x[pos.y][pos.x] << [images[sprited.image],sprited.flipped,pos.z,0.75]
      end

      entity_manager.each_entity Decorated, Position do |rec|
        dec, pos = rec.components
        # images[sprited.image].draw pos.x, pos.y, pos.z
        sorted_by_y_x[pos.y+dec.offset.y][pos.x+dec.offset.x] << [images[dec.image],false,pos.z+1, dec.scale]
      end


      sorted_by_y_x.keys.sort.each do |y|
        sorted_by_y_x[y].keys.sort.reverse.each do |x|
          sorted_by_y_x[y][x].each do |(img,flipped,z,sprite_scale)|
            x_scale = sprite_scale * (flipped ? 1 : -1)
            img.draw_rot x+RtsGame::TILE_SIZE/2,y+RtsGame::TILE_SIZE/2,z,0,0.5,0.5,x_scale,sprite_scale
          end
        end
      end

      entity_manager.each_entity Label, Position do |rec|
        label, pos = rec.components
        font = get_cached_font font: label.font, size: label.size
        font.draw(label.text, pos.x, pos.y, pos.z)
      end

      entity_manager.each_entity Attack, Position do |rec|
        attack, pos = rec.components
        font = get_cached_font size: 10
        if attack.current_cooldown > 0
          font.draw(attack.current_cooldown, pos.x+10, pos.y+50, ZOrder::HUD)
        end
      end

      entity_manager.each_entity Health, Position do |rec|
        h, pos = rec.components
        x = pos.x
        y = pos.y
        bg_c = Gosu::Color.rgba(255,255,255,128)
        hp_c = Gosu::Color.rgba(20,255,20,128)
        if h.points < h.max && h.points > 0
          draw_rect(target, x, y-10, ZOrder::HUD, 60, 10, bg_c)
          draw_rect(target, x+1, y-9, ZOrder::HUD, 58*(h.points.to_f/h.max), 8, hp_c)
        end
      end


      score_x = 50
      entity_manager.each_entity Base, PlayerOwned, Label do |rec|
        base, player, label = rec.components
        font = get_cached_font size: 48
        font.draw("#{label.text}: #{base.resource}", score_x, map.height*tile_size-100, ZOrder::HUD)
        score_x += map.width*tile_size-450
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
