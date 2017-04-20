class TimedLevelSystem
  def update(entity_manager, dt, input, res)
    results = entity_manager.find(Timed, Label, LevelTimer).first
    if results
      timed, label, lt = results.components
      label.text = (timed.accumulated_time_in_ms/1000).round(1)
    end
  end
end

class TimedSystem
  def update(entity_manager, delta, input, res)
    entity_manager.each_entity Timed do |rec|
      timed = rec.get(Timed)
      ent_id = rec.id
      timed.accumulated_time_in_ms += delta
    end
  end
end

class TimerSystem
  def update(entity_manager, delta, input, res)
    current_time_ms = input.total_time
    entity_manager.each_entity Timer do |rec|
      timer = rec.get(Timer)
      ent_id = rec.id

      if timer.expires_at
        if timer.expires_at < current_time_ms
          if timer.event
            event_comp = timer.event.is_a?(Class) ? timer.event.new : timer.event
            entity_manager.add_component component: event_comp, id: ent_id
          end
          if timer.repeat
            timer.expires_at = current_time_ms + timer.total
          else
            entity_manager.remove_component(klass: timer.class, id: ent_id)
          end
        end
      else
        timer.expires_at = current_time_ms + timer.total
      end

    end
  end
end

class MovementSystem
  def update(entity_manager, dt, input, res)
    # TODO add unit speed
    tile_size = RtsGame::TILE_SIZE
    speed = tile_size.to_f/(RtsGame::TURN_DURATION * 5)

    # TODO update tile info on unit creation
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
      pos.x += move.x
      pos.y += move.y

      # TODO track tile location / that's what we'll send to the client
      # TODO detect crossover of target point
      if (movement.target_vec - pos.to_vec).magnitude < 3
        pos.x = movement.target_vec.x.round
        pos.y = movement.target_vec.y.round

        base_ent = entity_manager.find(Base, PlayerOwned, Position).select{|ent| ent.get(PlayerOwned).id == pwn.id}.first
        base_pos = base_ent.get(Position)

        if base_pos.x - pos.x <= 1 && base_pos.y - pos.y <= 1
          base = base_ent.get(Base)
          unit_res_ent = entity_manager.find_by_id(ent_id, ResourceCarrier, Label)
          if unit_res_ent
            unit_res, unit_label = unit_res_ent.components
            base.resource += unit_res.resource
            unit_label.text = ""
            unit_res = 0
          end
        end

        # TODO update for visible range
        range = 3
        TileInfoHelper.update_tile_visibility(tile_infos[pwn.id], pos.x, pos.y, range)
        u.status = :idle
        # XXX ¯\_(ツ)_/¯ can I do this safely while iterating?
        entity_manager.remove_component(klass: MovementCommand, id: ent_id)
      end
    end
  end
end

class CommandSystem
  DIR_VECS = {
    'N' => vec(0,-1),
    'S' => vec(0,1),
    'W' => vec(-1,0),
    'E' => vec(1,0),
  }
  def update(entity_manager, dt, input, res)
    msgs = input[:messages]
    if msgs
      msgs.each do |msg|
        cmds = msg.data['commands']
        map_info = entity_manager.first(MapInfo).get(MapInfo)
        cmds.each do |cmd|
          c = cmd['command']
          uid = cmd['unit']

          if c == 'MOVE'
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned)
            u, pos, owner = ent.components

            if owner.id == msg.connection_id
              tile_size = RtsGame::TILE_SIZE
              target = pos.to_vec + DIR_VECS[cmd['dir']]*tile_size

              tile_x = (target.x / tile_size).floor
              tile_y = (target.y / tile_size).floor
              unless MapInfoHelper.blocked?(map_info, tile_x, tile_y) || u.status == :moving
                # TODO how to implement some sort of "has cmd" check?
                u.status = :moving
                entity_manager.add_component(id: uid, 
                                            component: MovementCommand.new(target_vec: target) )
              end
            end

          elsif c == 'GATHER'
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned)
            u, pos, owner = ent.components

            if owner.id == msg.connection_id
              tile_size = RtsGame::TILE_SIZE
              target = pos.to_vec + DIR_VECS[cmd['dir']]*tile_size

              tile_x = (target.x / tile_size).floor
              tile_y = (target.y / tile_size).floor

              res_info = MapInfoHelper.resource_at(map_info, tile_x, tile_y)
              if res_info

                rc = entity_manager.find_by_id(uid, ResourceCarrier).get(ResourceCarrier)

                resource_ent = entity_manager.find_by_id(res_info[:id], Resource, Label)
                resource = resource_ent.get(Resource)

                resource.total -= resource.value
                resource_ent.get(Label).text = "#{resource.value}/#{resource.total}"

                rc.resource = resource.value
                entity_manager.add_component(id: uid, component: Label.new(size:14,text:rc.resource))

                if resource.total <= 0
                  MapInfoHelper.remove_resource_at(map_info, tile_x, tile_y)
                  entity_manager.remove_entity(id: res_info[:id])
                end
              end

            end

          end
        end
      end
    end

  end
end

class SoundSystem
  def update(entity_manager, dt, input, res)
    entity_manager.each_entity SoundEffectEvent do |rec|
      ent_id = rec.id
      effect = rec.get(SoundEffectEvent)
      entity_manager.remove_component klass: effect.class, id: ent_id
      Gosu::Sample.new(effect.sound_to_play).play
    end
  end
end

