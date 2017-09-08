class AttackSystem
  def update(entity_manager, dt, input, res)
    attack_happened_this_tick = false

    map_info = entity_manager.first(MapInfo).get(MapInfo)
    tile_infos =  {}
    entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
      player, tile_info = ent.components
      tile_infos[player.id] = tile_info
    end

    entity_manager.each_entity(Unit, Attack) do |ent|
      u, attack = ent.components

      if attack.current_cooldown > 0
        attack.current_cooldown -= 1
        u.dirty = true
        if attack.current_cooldown == 0
          attack.can_attack = true
        end
      end
    end

    entity_manager.each_entity(Unit, MeleeCommand, Melee, Attack, Position, PlayerOwned, Sprited) do |ent|
      u, cmd, melee, attack, pos, player, sprite = ent.components
      entity_manager.remove_component klass: MeleeCommand, id: ent.id
      next if u.status == :dead || !attack.can_attack
      target_ent = entity_manager.find_by_id(cmd.target, Unit, Position, Health, PlayerOwned)
      if target_ent.nil?
        puts "MELEE on an unknown target: #{cmd.target}"
        next
      end
      t_pos = target_ent.get(Position)
      dir_x = t_pos.tile_x - pos.tile_x
      dx = dir_x.abs
      dy = (t_pos.tile_y - pos.tile_y).abs
      next unless dx <= 1 && dy <= 1

      if dir_x > 0
        sprite.flipped = true
      elsif dir_x < 0
        sprite.flipped = false
      end
      attack.current_cooldown = attack.cooldown
      attack.can_attack = false

      u.dirty = true

      tx = pos.tile_x+dx
      ty = pos.tile_y+dy
      tile_size = RtsGame::TILE_SIZE

      target_health = target_ent.get(Health)
      target_unit = target_ent.get(Unit)

      next if target_unit.status == :dead
      Prefab.melee(entity_manager: entity_manager, x: t_pos.x, y: t_pos.y)

      target_unit.dirty = true

      tile_infos.values.each do |tile_info|
        TileInfoHelper.dirty_tile(tile_info, tx, ty)
      end

      attack_happened_this_tick = true
      target_health.points = [target_health.points-attack.damage, 0].max
      target_player = target_ent.get(PlayerOwned)

      kill_unit!(entity_manager, target_ent.id, target_unit, target_player.id, ent.id, u, player.id) if target_health.points <= 0
    end

    entity_manager.each_entity(Unit, ShootCommand, Shooter, Attack, Position, PlayerOwned, Sprited) do |ent|
      u, cmd, shooter, attack, pos, player, sprite = ent.components
      entity_manager.remove_component klass: ShootCommand, id: ent.id
      next if u.status == :dead || !attack.can_attack

      range = attack.range
      # they shoot farther on the diagonal.. sue me  ;)
      dx = cmd.dx
      dy = cmd.dy
      tile_size = RtsGame::TILE_SIZE
      next unless dx.abs <= range && dy.abs <= range

      if dx > 0
        sprite.flipped = true
      elsif dx < 0
        sprite.flipped = false
      end
      attack.current_cooldown = attack.cooldown
      attack.can_attack = false
      u.dirty = true

      tx = pos.tile_x+dx
      ty = pos.tile_y+dy

      tile_infos.values.each do |tile_info|
        TileInfoHelper.dirty_tile(tile_info, tx, ty)
      end
      tile_units = MapInfoHelper.units_at(map_info, tx, ty)
      if tile_units.size > 0
        Prefab.explosion(entity_manager: entity_manager, x: tx*tile_size, y: ty*tile_size)
        Prefab.laser(entity_manager: entity_manager, pid: player.id, x: pos.x, y: pos.y, x2: tx*tile_size, y2: ty*tile_size)
      end

      tile_units.each do |tu_id|
        target_ent = entity_manager.find_by_id(tu_id, Unit, Health, PlayerOwned)
        target_health = target_ent.get(Health)
        target_unit = target_ent.get(Unit)
        next if target_unit.status == :dead
        target_unit.dirty = true

        attack_happened_this_tick = true
        target_health.points = [target_health.points-attack.damage, 0].max
        target_player = target_ent.get(PlayerOwned)
        kill_unit!(entity_manager, target_ent.id, target_unit, target_player.id, ent.id, u, player.id) if target_health.points <= 0
      end
    end

    entity_manager.each_entity(MeleeCommand) do |ent|
      entity_manager.remove_component klass: MeleeCommand, id: ent.id
    end
    entity_manager.each_entity(ShootCommand) do |ent|
      entity_manager.remove_component klass: ShootCommand, id: ent.id
    end

    music_info = entity_manager.find(MusicInfo).first.get(MusicInfo)
    if attack_happened_this_tick
      music_info.mood = :battle
      music_info.peace_timer = 0
    else
      music_info.peace_timer += 1
    end
    if music_info.peace_timer > (RtsGame::STEPS_PER_TURN * RtsGame::TURNS_PER_SECOND * 10)
      music_info.mood = :peace
    end

  end

  private
  def kill_unit!(entity_manager, id, target_unit, target_player_id, killer_id, killer_unit, killer_player_id)
    puts "Player #{killer_player_id} #{killer_unit.type}[#{killer_id}] killed  player #{target_player_id} #{target_unit.type}[#{id}]"
    target_unit.status = :dead
    target_player_info = entity_manager.query(Q.must(PlayerOwned).with(id: target_player_id).must(PlayerInfo)).first.components.last

    getter = "#{target_unit.type}_count"
    setter = "#{target_unit.type}_count="
    target_player_info.send(setter, target_player_info.send(getter)-1)
    target_player_info.death_count += 1

    killer_player_info = entity_manager.query(Q.must(PlayerOwned).with(id: killer_player_id).must(PlayerInfo)).first.components.last
    killer_player_info.kill_count += 1

    if target_unit.type == :base
      base = entity_manager.find_by_id(id, Base).get(Base)
      base.resource = 0
    end

    # TODO drop their resources?
    # TODO possibly change sprite to splat on death?
    entity_manager.remove_component(klass: Sprited, id: id)
    entity_manager.remove_component(klass: ResourceCarrier, id: id)
    entity_manager.remove_component(klass: Label, id: id) unless target_unit.type == :base
    entity_manager.remove_component(klass: Decorated, id: id)

  end
end

