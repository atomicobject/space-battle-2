 module Prefab
  def self.laser(entity_manager:,pid:,x:,y:,x2:,y2:)
    dx = x2-x
    dy = y-y2
    # dist = Math.sqrt(dx*dx+dy*dy)
    # radians = Math.atan2(dy, dx)
    # degs = radians * 180.0/Math::PI
    # degs = degs + 360 if degs < 0

    w = 2
    off = RtsGame::TILE_SIZE/2
    eid = entity_manager.add_entity(
      Position.new(x:x+dx/2, y:y+dy/2, z:90),
      Textured.new(image: "laser#{pid}".to_sym, 
        x1: off+x-w, y1: off+y-w, 
        x2: off+x+w, y2: off+y+w,
        x3: off+x2-w, y3: off+y2-w, 
        x4: off+x2+w, y4: off+y2+w)
    )
    timer_name = "death-laser-#{eid}"
    entity_manager.add_component component: Timer.new(timer_name, 1000, false, DeathEvent), id: eid
    eid
  end

  def self.explosion(entity_manager:,x:,y:)
    timings = {
      explosion1: 39,
      explosion2: 59,
      explosion3: 59,
      explosion4: 39,
    }
    frames = [ :explosion1, :explosion2, :explosion3, :explosion4 ]

    x += rand(-30..30)
    y += rand(-30..30)
    eid = entity_manager.add_entity(
      Position.new(x:x, y:y, z:20),
      Sprited.new(image: frames.first, flipped: false, offset: vec),
      Animated.new(timings: timings, frames: frames, index: 0, loop: false, time: 0),
      SoundEffectEvent.new(sound_to_play: [:explosion_sound1, :explosion_sound2].sample)
    )
    timer_name = "death-explosion-#{eid}"
    entity_manager.add_component component: Timer.new(timer_name, timings.values.sum*100, false, DeathEvent), id: eid
    eid
  end

  def self.melee(entity_manager:,x:,y:)
    timings = {
      melee1: 39,
      melee2: 59,
      melee3: 59,
      melee4: 39,
    }
    melee_frames = [ :melee1, :melee2, :melee3, :melee4 ]
    frames = melee_frames.sample(2)

    x += rand(-20..20)
    y += rand(-20..20)
    eid = entity_manager.add_entity(
      Position.new(x:x, y:y, z:20),
      Sprited.new(image: frames.first, flipped: false, offset: vec),
      Animated.new(timings: timings, frames: frames, index: 0, loop: false, time: 0),
      SoundEffectEvent.new(sound_to_play: [:melee_sound1, :melee_sound2].sample)
    )
    timer_name = "death-melee-#{eid}"
    entity_manager.add_component component: Timer.new(timer_name, 140*100, false, DeathEvent), id: eid
    eid
  end

  def self.base(entity_manager:,x:,y:,player_id:,map_info:,name:)
    entity_manager.add_entity PlayerOwned.new(id: player_id), TileInfo.new

    b = Base.new(resource: RtsGame::PLAYER_START_RESOURCE)
    r = Ranged.new(distance: RtsGame::UNITS[:base][:range])

    hp = RtsGame::UNITS[:base][:hp]
    health = Health.new(points: hp, max: hp)
    tile_size = RtsGame::TILE_SIZE

    player_name = name || "Player"
    entity_manager.add_entity(
      Label.new(size: 24, text: "#{player_name} (#{player_id+1})"),
      PlayerOwned.new(id: player_id),
      Named.new(name: 'player-name')
    )

    id = entity_manager.add_entity(
      Unit.new(status: :idle, type: :base),
      b,
      Position.new(x:x, y:y, tile_x: (x/tile_size).floor, tile_y: (y/tile_size).floor, z:1),
      PlayerOwned.new(id: player_id),
      PlayerInfo.new(id: player_id, 
        base_count: 1,
        worker_count: RtsGame::STARTING_WORKERS, 
        tank_count: 0, scout_count: 0,
        kill_count: 0, total_units: RtsGame::STARTING_WORKERS+1,
        death_count: 0, total_resources: RtsGame::PLAYER_START_RESOURCE,
        total_commands: 0, invalid_commands: 0,
        ),
      Sprited.new(image: "base#{player_id}".to_sym, flipped: false, offset: vec, scale: 0.35),
      r,
      health
    )
    puts "#{player_id}: BASE: #{id}"

    tile_size = RtsGame::TILE_SIZE
    tile_x = (x/tile_size).floor
    tile_y = (y/tile_size).floor
    MapInfoHelper.add_unit_at(map_info,tile_x,tile_y,id)
    id
  end

  def self.unit(type:,entity_manager:,x:,y:,player_id:,map_info:)
    unit_def = RtsGame::UNITS[type.to_sym]
    health = Health.new(points: unit_def[:hp], max: unit_def[:hp])
    tile_size = RtsGame::TILE_SIZE
    scale = type.to_sym == :tank ? 0.6 : 0.3
    id = entity_manager.add_entity(
      Unit.new(type: type.to_sym),
      Position.new(x:x, y:y, tile_x: (x/tile_size).floor, tile_y: (y/tile_size).floor),
      Ranged.new(distance: unit_def[:range]),
      Attack.new(damage: unit_def[:attack_damage],
                 range: unit_def[:range],
                 cooldown: unit_def[:attack_cooldown_duration],
                 current_cooldown: 0,
                 can_attack: true
                ),
      Speed.new(speed: unit_def[:speed]),
      PlayerOwned.new(id: player_id),
      Sprited.new(image: "#{type}#{player_id}".to_sym, 
        flipped: false, 
        scale: scale,
        offset: vec(rand(-8..8),rand(-8..8))),
      Label.new(size: 14),
      health
    )

    puts "#{player_id}: #{type.to_s.upcase}: #{id}"
    entity_manager.add_component component: ResourceCarrier.new, id: id if unit_def[:can_carry]
    entity_manager.add_component component: Shooter.new, id: id if unit_def[:attack_type] == :ranged
    entity_manager.add_component component: Melee.new, id: id if unit_def[:attack_type] == :melee

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
    id = entity_manager.add_entity res, Label.new(size:16,text:res.total.to_s), Position.new(x:x, y:y), Sprited.new(image: "#{type}_res1".to_sym, offset: vec)

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

  def self.timer(entity_manager:,time:)
    timer = Timer.new("end-of-game", time)
    timer.keep = true
    entity_manager.add_entity(timer)
  end

  def self.map(player_count:, entity_manager:, resources:, player_names:)
    music_info(entity_manager: entity_manager)
    info = map_info(entity_manager: entity_manager, static_map: resources[:map])
    bases(player_count: player_count, player_names: player_names, entity_manager: entity_manager, static_map: resources[:map], map_info: info)
    resources(entity_manager: entity_manager, static_map: resources[:map], map_info: info)
  end

  def self.bases(player_count:, entity_manager:, static_map:, map_info:, player_names:)
    bases = static_map.objects.select{|o|o['type'] == "base"}.shuffle
    player_count.times do |i|
      start_point = vec(bases[i].x, bases[i].y-RtsGame::TILE_SIZE)
      base(entity_manager: entity_manager, x: start_point.x, y: start_point.y,
           player_id: i, map_info: map_info, name: player_names[i])

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

  def self.music_info(entity_manager:)
    peace_music = [:peace_music1, :peace_music2, :peace_music3]
    entity_manager.add_entity MusicInfo.new(mood: :peace, battle: :battle_music1, peace: peace_music.sample, peace_music: peace_music, peace_timer: 99_999)
  end

end
