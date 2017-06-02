class AttackSystem
  def update(entity_manager, dt, input, res)
    map_info = entity_manager.first(MapInfo).get(MapInfo)
    tile_infos =  {} 
    entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
      player, tile_info = ent.components
      tile_infos[player.id] = tile_info
    end

    entity_manager.each_entity(MeleeEffect) do |ent|
      entity_manager.remove_entity(id: ent.id)
    end
    entity_manager.each_entity(Explosion) do |ent|
      entity_manager.remove_entity(id: ent.id)
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

    entity_manager.each_entity(Unit, MeleeCommand, Melee, Attack, Position) do |ent|
      u, cmd, melee, attack, pos = ent.components
      entity_manager.remove_component klass: MeleeCommand, id: ent.id
      next if u.status == :dead || !attack.can_attack 
      target_ent = entity_manager.find_by_id(cmd.target, Unit, Position, Health)
      if target_ent.nil?
        puts "MELEE on an unknown target: #{cmd.target}"
        next
      end
      t_pos = target_ent.get(Position)
      dx = (t_pos.tile_x - pos.tile_x).abs
      dy = (t_pos.tile_y - pos.tile_y).abs
      next unless dx <= 1 && dy <= 1
      attack.current_cooldown = attack.cooldown
      attack.can_attack = false

      u.dirty = true

      tx = pos.tile_x+dx
      ty = pos.tile_y+dy
      tile_size = RtsGame::TILE_SIZE
      Prefab.melee(entity_manager: entity_manager, x: tx*tile_size, y: ty*tile_size)

      target_health = target_ent.get(Health)
      target_unit = target_ent.get(Unit)
      target_unit.dirty = true

      tile_infos.values.each do |tile_info|
        TileInfoHelper.dirty_tile(tile_info, tx, ty)
      end

      target_health.points = [target_health.points-attack.damage, 0].max
      target_health.points = 1 if target_health.points <= 0 && target_unit.type == :base

      kill_unit!(entity_manager, target_ent.id, target_unit, ent.id, u) if target_health.points <= 0
    end

    entity_manager.each_entity(Unit, ShootCommand, Shooter, Attack, Position) do |ent|
      u, cmd, shooter, attack, pos = ent.components
      entity_manager.remove_component klass: ShootCommand, id: ent.id
      next if u.status == :dead || !attack.can_attack

      range = attack.range
      # they shoot farther on the diagonal.. sue me  ;)
      dx = cmd.dx
      dy = cmd.dy
      tile_size = RtsGame::TILE_SIZE
      next unless dx.abs <= range && dy.abs <= range

      attack.current_cooldown = attack.cooldown
      attack.can_attack = false
      u.dirty = true

      tx = pos.tile_x+dx
      ty = pos.tile_y+dy

      Prefab.explosion(entity_manager: entity_manager, x: tx*tile_size, y: ty*tile_size)

      tile_infos.values.each do |tile_info|
        TileInfoHelper.dirty_tile(tile_info, tx, ty)
      end
      tile_units = MapInfoHelper.units_at(map_info, tx, ty)
      tile_units.each do |tu_id|
        target_ent = entity_manager.find_by_id(tu_id, Unit, Health)
        target_health = target_ent.get(Health)
        target_unit = target_ent.get(Unit)
        target_unit.dirty = true

        target_health.points = [target_health.points-attack.damage, 0].max
        target_health.points = 1 if target_health.points <= 0 && target_unit.type == :base

        kill_unit!(entity_manager, target_ent.id, target_unit, ent.id, u) if target_health.points <= 0
      end
    end

    entity_manager.each_entity(MeleeCommand) do |ent|
      entity_manager.remove_component klass: MeleeCommand, id: ent.id
    end
    entity_manager.each_entity(ShootCommand) do |ent|
      entity_manager.remove_component klass: ShootCommand, id: ent.id
    end

  end

  private
  def kill_unit!(entity_manager, id, target_unit, killer_id, killer_unit)
    puts "#{killer_unit.type}[#{killer_id}] killed #{target_unit.type}[#{id}]"
    target_unit.status = :dead

    # TODO drop their resources?
    # TODO possibly change sprite to splat on death?
    entity_manager.remove_component(klass: Sprited, id: id)
    entity_manager.remove_component(klass: ResourceCarrier, id: id)
    entity_manager.remove_component(klass: Label, id: id)
  end
end

