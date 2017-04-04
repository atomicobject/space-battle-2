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

        # TODO more info than just 'true'
        # TODO update for visible range as well
        tile_x = (pos.x.to_f/tile_size).floor
        tile_y = (pos.y.to_f/tile_size).floor
        # TODO add unit range
        range = 3
        ((tile_x-range)..(tile_x+range)).each do |x|
          ((tile_y-range)..(tile_y+range)).each do |y|
            tile_infos[pwn.id].tiles[x][y] = true
          end
        end

        u.status = :idle
        # XXX can I do this safely while iterating?
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
              unless res[:map].blocked?(tile_x, tile_y)
                u.status = :moving
                entity_manager.add_component(id: uid, 
                                            component: MovementCommand.new(target_vec: target) )
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

