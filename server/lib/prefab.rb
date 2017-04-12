module Prefab
  include Gosu

  def self.base(entity_manager:,x:,y:,player_id:)
    entity_manager.add_entity PlayerOwned.new(id: player_id), TileInfo.new

    entity_manager.add_entity Unit.new(status: :base), Base.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :base1)
  end

  def self.worker(entity_manager:,x:,y:,player_id:)
    entity_manager.add_entity Unit.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :worker1)
  end

  def self.map_info(entity_manager:,static_map:)
    info = MapInfo.new(static_map.width, static_map.height)

    static_map.width.times do |i|
      static_map.height.times do |j|
        MapInfoHelper.init_at(info, i, j, static_map.at(i,j))
      end
    end

    entity_manager.add_entity(info)
  end

  def self.map(entity_manager:, resources:)
    map_info(entity_manager: entity_manager, static_map: resources[:map])

    start_point = vec(3, 4)*64
    base(entity_manager: entity_manager, x: start_point.x, y: start_point.y, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x + 64, y: start_point.y + 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x - 64, y: start_point.y + 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x + 64, y: start_point.y - 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x - 64, y: start_point.y - 64, player_id: 0)

  end

end
