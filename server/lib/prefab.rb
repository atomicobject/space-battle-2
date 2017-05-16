 module Prefab
  include Gosu

  def self.base(entity_manager:,x:,y:,player_id:,map_info:)
    entity_manager.add_entity PlayerOwned.new(id: player_id), TileInfo.new

    b = Base.new(resource: RtsGame::PLAYER_START_RESOURCE)
    r = Ranged.new(distance: RtsGame::UNITS[:base][:range])
    id = entity_manager.add_entity Unit.new(status: :base, type: :base), b, Position.new(x:x, y:y, z:10), PlayerOwned.new(id: player_id), Sprited.new(image: :base1), Label.new(size: 24, text: b.resource), r

    tile_size = RtsGame::TILE_SIZE
    tile_x = (x/tile_size).floor
    tile_y = (y/tile_size).floor
    MapInfoHelper.add_unit_at(map_info,tile_x,tile_y,id)
    id
  end

  def self.unit(type:,entity_manager:,x:,y:,player_id:,map_info:)
    unit_def = RtsGame::UNITS[type.to_sym]
    id = entity_manager.add_entity(
      Unit.new(type: type.to_sym),
      Position.new(x:x, y:y),
      Ranged.new(distance: unit_def[:range]),
      Speed.new(speed: unit_def[:speed]),
      Health.new(points: unit_def[:hp]),
      PlayerOwned.new(id: player_id),
      Sprited.new(image: type.to_sym),
    )
    entity_manager.add_component component: ResourceCarrier.new, id: id if unit_def[:can_carry]

    tile_size = RtsGame::TILE_SIZE
    tile_x = (x/tile_size).floor
    tile_y = (y/tile_size).floor
    MapInfoHelper.add_unit_at(map_info,tile_x,tile_y,id)
    id
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

  def self.timer(entity_manager:)
    timer = Timer.new("end-of-game", RtsGame::GAME_LENGTH_IN_MS)
    timer.keep = true
    entity_manager.add_entity(timer)
  end

  def self.map(player_count:, entity_manager:, resources:)

    info = map_info(entity_manager: entity_manager, static_map: resources[:map])

    bases(player_count: player_count, entity_manager: entity_manager, static_map: resources[:map], map_info:  info)

    resources(entity_manager: entity_manager, static_map: resources[:map], map_info: info)
  end

  def self.bases(player_count:, entity_manager:, static_map:, map_info:)
    bases = static_map.objects.select{|o|o['type'] == "base"}
    player_count.times do |i|
      start_point = vec(bases[i].x, bases[i].y)
      base(entity_manager: entity_manager, x: start_point.x, y: start_point.y, 
           player_id: i, map_info: map_info)

      RtsGame::STARTING_WORKERS.times do
        unit(type: :worker, entity_manager: entity_manager, 
             player_id: i, map_info: map_info,
             x: start_point.x, y: start_point.y)
      end
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
