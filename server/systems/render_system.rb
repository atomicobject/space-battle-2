module ZOrder
  Terrain, Env, Units, HUD, Debug = *(0..100)
end


class RenderSystem

  def initialize
    @font_cache = {}
    @color_cache = {}
  end

  def get_cached_font(font:,size:)
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
          # t.units.each do |u|
          #   images[u.image].draw base_x, base_y, ZOrder::Units
          # end

        end
      end

#       entity_manager.each_entity Sprited, Position, Unit, PlayerOwned, Position do |rec|
#         if rec.get(PlayerOwned).id == 0
#           if rec.get(Unit).type == :worker
#             pos = rec.get(Position).to_vec
#             if @prev
#               puts "DIFF: #{@prev - pos}"
#             end
#             @prev = pos
#           end
#         end
#       end
#
      entity_manager.each_entity Sprited, Position do |rec|
        sprited, pos = rec.components
        images[sprited.image].draw pos.x, pos.y, pos.z
      end

      entity_manager.each_entity Label, Position do |rec|
        label, pos = rec.components
        font = get_cached_font font: label.font, size: label.size
        font.draw(label.text, pos.x, pos.y, pos.z)
      end

      # map.width.times do |x|
      #   target.draw_line(x*tile_size, 0, Gosu::Color::RED, x*tile_size, map.height*tile_size, Gosu::Color::RED, ZOrder::Debug)
      # end
      # map.height.times do |y|
      #   target.draw_line(0, y*tile_size, Gosu::Color::RED, map.width*tile_size, y*tile_size, Gosu::Color::RED, ZOrder::Debug)
      # end
    end
  end
end
