 module Prefab
  include Gosu

  def self.base(entity_manager:,x:,y:,player_id:,map_info:)
    tile_info = TileInfo.new
    entity_manager.add_entity PlayerOwned.new(id: player_id), tile_info

    b = Base.new(resource: RtsGame::PLAYER_START_RESOURCE)
    entity_manager.add_entity Unit.new(status: :base), b, Position.new(x:x, y:y, z:10), PlayerOwned.new(id: player_id), Sprited.new(image: :base1), Label.new(size: 24, text: b.resource)

    range = 3
    TileInfoHelper.update_tile_visibility(tile_info, x, y, range)

    tile_info
  end

  def self.worker(entity_manager:,x:,y:,player_id:,tile_info:)
    entity_manager.add_entity Unit.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :worker1), ResourceCarrier.new

    range = 3
    TileInfoHelper.update_tile_visibility(tile_info, x, y, range)
  end

  def self.resource(entity_manager:,x:,y:,map_info:,type:)
    if type == 'small'
      res = Resource.new(total: 200, value:10)
    else
      res = Resource.new(total: 1000, value:20)
    end
    id = entity_manager.add_entity res, Label.new(size:16,text:"#{res.value}/#{res.total}"), Position.new(x:x, y:y), Sprited.new(image: "#{type}_res1".to_sym)

    # TODO where should world => tile coord conversion happen
    tile_size = RtsGame::TILE_SIZE
    tile_x = (x/tile_size).floor
    tile_y = (y/tile_size).floor

    MapInfoHelper.add_resource_at(map_info,tile_x,tile_y,
                                  id: id, type: :small, total:res.total, value:res.value)
    id
  end

  def self.map_info(entity_manager:,static_map:)
    info = MapInfo.new(static_map.width, static_map.height)

    static_map.width.times do |i|
      static_map.height.times do |j|
        MapInfoHelper.init_at(info, i, j, static_map.at(i,j))
      end
    end

    entity_manager.add_entity(info)
    info
  end

  def self.map(entity_manager:, resources:)
    info = map_info(entity_manager: entity_manager, static_map: resources[:map])

    bases(player_count: 1, entity_manager: entity_manager, static_map: resources[:map], map_info:  info)

    resources(entity_manager: entity_manager, static_map: resources[:map], map_info: info)
  end

  def self.bases(player_count:, entity_manager:, static_map:, map_info:)
    bases = static_map.objects.select{|o|o['type'] == "base"}
    player_count.times do |i|
      start_point = vec(bases[i].x, bases[i].y)
      tile_info = base(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
           player_id: i, map_info: map_info)

      worker(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
             player_id: i, tile_info: tile_info)
      worker(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
             player_id: i, tile_info: tile_info)
      worker(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
             player_id: i, tile_info: tile_info)
      worker(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
             player_id: i, tile_info: tile_info)
    end
  end

  def self.resources(entity_manager:, static_map:, map_info:)
    tile_size = RtsGame::TILE_SIZE
    static_map.objects.select{|o|o['type'] == "small_resource"}.each do |res|
      resource(entity_manager: entity_manager, x: res.x, y: res.y-tile_size, map_info: map_info, type: "small")
    end
    static_map.objects.select{|o|o['type'] == "large_resource"}.each do |res|
      resource(entity_manager: entity_manager, x: res.x, y: res.y-tile_size, map_info: map_info, type: "large")
    end
  end

end
