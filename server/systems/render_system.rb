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
      map.width.times do |x|
        map.height.times do |y|
          t = map.at(x,y)
          base_x = x*tile_size
          base_y = y*tile_size
          # puts "#{base_x},#{base_y}"
          img = images[t.image]
          puts "could not find image for: #{t.image}" unless img
          img.draw base_x, base_y, ZOrder::Terrain

          t.objects.each do |obj|
            images[obj.image].draw base_x, base_y, ZOrder::Env
          end
        end
      end

      entity_manager.each_entity Sprited, Position do |rec|
        sprited, pos = rec.components
        images[sprited.image].draw pos.x, pos.y, pos.z
      end

      entity_manager.each_entity Label, Position do |rec|
        label, pos = rec.components
        font = get_cached_font font: label.font, size: label.size
        font.draw(label.text, pos.x, pos.y, pos.z)
      end

      score_x = 50
      entity_manager.each_entity Base, PlayerOwned do |rec|
        base, player = rec.components
        font = get_cached_font size: 48
        font.draw("Player #{player.id}: #{base.resource}", score_x, map.height*tile_size-100, ZOrder::HUD)
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

  def format_time_string(ms)
    seconds = ms/1000
    Time.at(seconds).strftime("%M:%S")
  end
end
