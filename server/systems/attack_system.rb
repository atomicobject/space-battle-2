class AttackSystem
  def update(entity_manager, dt, input, res)
    map_info = entity_manager.first(MapInfo).get(MapInfo)

    entity_manager.each_entity(Unit, AttackCommand, Attack, Position) do |ent|
      u, cmd, attack, pos = ent.components
      entity_manager.remove_component klass: AttackCommand, id: ent.id
      next if u.status == :dead

      range = attack.range
      # they shoot farther on the diagonal.. sue me  ;)
      dx = cmd.dx
      dy = cmd.dy
      tile_size = RtsGame::TILE_SIZE
      tile_x = (pos.x/tile_size).floor
      tile_y = (pos.y/tile_size).floor
      next unless dx.abs <= range && dy.abs <= range

      tile_units = MapInfoHelper.units_at(map_info, tile_x+dx, tile_y+dy)
      puts "#{tile_units.size} targets"
      tile_units.each do |tu_id|
        target_ent = entity_manager.find_by_id(tu_id, Unit, Health)
        target_health = target_ent.get(Health)
        target_health.points = [target_health.points-attack.damage, 0].max
        if target_health.points <= 0
          # TODO add dead checks to commands for those units
          target_unit = target_ent.get(Unit)
          target_unit.status = :dead
          target_unit.dirty = true

          # TODO possibly change sprite to splat on death?
          entity_manager.remove_component(klass: Sprited, id: tu_id)
        end

      end
    end
  end
end

