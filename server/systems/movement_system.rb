class MovementSystem

  def update(entity_manager, dt, input, res)
    tile_infos =  {}
    entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
      player, tile_info = ent.components
      tile_infos[player.id] = tile_info
    end

    tile_size = RtsGame::TILE_SIZE
    base_speed = tile_size.to_f/(RtsGame::TURN_DURATION * 5 - RtsGame::SIMULATION_STEP)
    entity_manager.each_entity PlayerOwned, Unit, MovementCommand, Position, Speed, Sprited do |ent|
      pwn, u, movement, pos, s, sprite = ent.components

      ent_id = ent.id

      if u.status == :dead
        entity_manager.remove_component(klass: MovementCommand, id: ent_id)
        next
      end
      u.status = :moving
      u.dirty = true

      speed = tile_size.to_f/(RtsGame::TURN_DURATION * s.speed - RtsGame::SIMULATION_STEP)

      displacement = movement.target_vec - pos.to_vec
      dist = displacement.magnitude
      move = (displacement.unit * dt * speed).clip_to(dist) # clip any overshoot

      pre_move_pos = pos.deep_clone
      pos.x += move.x
      pos.y += move.y
      if move.x > 0
        pos.rotation = 90
      elsif move.x < 0
        pos.rotation = 270
      elsif move.y < 0
        pos.rotation = 0
      elsif move.y > 0
        pos.rotation = 180
      end

      # semi arbitrarily set to 1/4 the distance a unit could travel in a simulation step
      #   should be much larger than any rounding error
      #   and much smaller than any real/indented gap
      close_enough = RtsGame::SIMULATION_STEP/4.0 * speed

      if (movement.target_vec - pos.to_vec).magnitude <= close_enough
        map_info = entity_manager.first(MapInfo).get(MapInfo)
        pre_tile_x = pre_move_pos.tile_x
        pre_tile_y = pre_move_pos.tile_y
        MapInfoHelper.remove_unit_from(map_info,pre_tile_x,pre_tile_y,ent_id)

        pos.x = movement.target_vec.x.round
        pos.y = movement.target_vec.y.round

        tile_x = (pos.x.to_f/tile_size).floor
        tile_y = (pos.y.to_f/tile_size).floor
        pos.tile_x = tile_x
        pos.tile_y = tile_y
        MapInfoHelper.add_unit_at(map_info,tile_x,tile_y,ent_id)
        u.dirty = true
        u.status = :idle

        base_ent = entity_manager.find(Base, Unit, PlayerOwned, Position).select{|ent| ent.get(PlayerOwned).id == pwn.id}.first
        base_pos = base_ent.get(Position)
        owner = base_ent.get(PlayerOwned)

        if (tile_x - base_pos.tile_x).abs <= 1 && (tile_y - base_pos.tile_y).abs <= 1
          base = base_ent.get(Base)
          unit_res_ent = entity_manager.find_by_id(ent_id, ResourceCarrier, Decorated)
          if unit_res_ent
            unit_res, unit_dec = unit_res_ent.components
            base.resource += unit_res.resource
            player_info = entity_manager.query(Q.must(PlayerOwned).
              with(id: owner.id).must(PlayerInfo)).first.components.last
            player_info.total_resources += unit_res.resource
            base_ent.get(Unit).dirty = true
            unit_res.resource = 0

            # entity_manager.add_component id: base_ent.id, component: SoundEffectEvent.new(sound_to_play: :collect_sound)
            entity_manager.remove_component(klass: Decorated, id: ent_id)
          end
        end

        tile_infos.values.each do |tile_info|
          TileInfoHelper.dirty_tile(tile_info, tile_x, tile_y)
          TileInfoHelper.dirty_tile(tile_info, pre_tile_x, pre_tile_y)
        end

        entity_manager.remove_component(klass: MovementCommand, id: ent_id)
      end
    end
  end
end

