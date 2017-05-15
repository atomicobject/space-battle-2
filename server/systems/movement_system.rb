class MovementSystem
  def update(entity_manager, dt, input, res)
    # TODO add unit speed
    tile_size = RtsGame::TILE_SIZE
    speed = tile_size.to_f/(RtsGame::TURN_DURATION * 5)

    tile_infos =  {} 
    entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
      player, tile_info = ent.components
      tile_infos[player.id] = tile_info
    end
      
    # TODO what about non-player owned movement? sep query?
    entity_manager.each_entity PlayerOwned, Unit, MovementCommand, Position do |ent|
      pwn, u, movement, pos = ent.components
      ent_id = ent.id

      dir = movement.target_vec - pos.to_vec
      move = dir.unit * dt * speed

      pre_move_pos = pos.deep_clone
      pos.x += move.x
      pos.y += move.y

      # TODO detect crossover of target point (overshoot possible)
      close_enough = 10.0/RtsGame::TURN_DURATION
      if dir.magnitude < close_enough
        map_info = entity_manager.first(MapInfo).get(MapInfo)
        pre_tile_x = (pre_move_pos.x/tile_size).floor
        pre_tile_y = (pre_move_pos.y/tile_size).floor
        MapInfoHelper.remove_unit_from(map_info,pre_tile_x,pre_tile_y,ent_id)

        pos.x = movement.target_vec.x.round
        pos.y = movement.target_vec.y.round

        tile_x = (pos.x/tile_size).floor
        tile_y = (pos.y/tile_size).floor
        MapInfoHelper.add_unit_at(map_info,tile_x,tile_y,ent_id)
        u.dirty = true
        u.status = :idle

        base_ent = entity_manager.find(Base, PlayerOwned, Position, Label).select{|ent| ent.get(PlayerOwned).id == pwn.id}.first
        base_pos = base_ent.get(Position)

        if (base_pos.x - pos.x).abs <= 1 && (base_pos.y - pos.y).abs <= 1
          base = base_ent.get(Base)
          unit_res_ent = entity_manager.find_by_id(ent_id, ResourceCarrier, Label)
          if unit_res_ent
            unit_res, unit_label = unit_res_ent.components
            base.resource += unit_res.resource
            base_ent.get(Label).text = base.resource
            unit_res.resource = 0
            unit_label.text = ""
          end
        end

        # TODO dirty its previous tile somehow...  :/
        tile_infos.values.each do |tile_info|
          TileInfoHelper.dirty_tile(tile_info, pos.x, pos.y)
        end

        entity_manager.remove_component(klass: MovementCommand, id: ent_id)
      end
    end
  end
end

