class AttackSystem
  def update(entity_manager, dt, input, res)
    map_info = entity_manager.first(MapInfo).get(MapInfo)

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

    entity_manager.each_entity(Unit, AttackCommand, Attack, Position) do |ent|
      u, cmd, attack, pos = ent.components
      entity_manager.remove_component klass: AttackCommand, id: ent.id
      next if u.status == :dead || !attack.can_attack

      range = attack.range
      # they shoot farther on the diagonal.. sue me  ;)
      dx = cmd.dx
      dy = cmd.dy
      tile_size = RtsGame::TILE_SIZE

      # XXX it's not "in" this tile yet!
      # it is on its way there... how to look up its current grid location?
      tile_x = (pos.x.to_f/tile_size).floor
      tile_y = (pos.y.to_f/tile_size).floor

      next unless dx.abs <= range && dy.abs <= range

      attack.current_cooldown = attack.cooldown
      attack.can_attack = false
      u.dirty = true

      tx = tile_x+dx
      ty = tile_y+dy

      Prefab.explosion(entity_manager: entity_manager, x: tx*tile_size, y: ty*tile_size)

      tile_units = MapInfoHelper.units_at(map_info, tx, ty)
      tile_units.each do |tu_id|
        target_ent = entity_manager.find_by_id(tu_id, Unit, Health)
        target_health = target_ent.get(Health)
        target_health.points = [target_health.points-attack.damage, 0].max
        if target_health.points <= 0
          target_unit = target_ent.get(Unit)
          target_unit.status = :dead
          target_unit.dirty = true

          # TODO drop their resources?
          # TODO possibly change sprite to splat on death?
          entity_manager.remove_component(klass: Sprited, id: tu_id)
          entity_manager.remove_component(klass: ResourceCarrier, id: tu_id)
          entity_manager.remove_component(klass: Label, id: tu_id)
        end

      end
    end

  end
end

