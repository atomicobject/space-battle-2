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
    speed = 64.0/1000

    entity_manager.each_entity Unit, MovementCommand, Position do |ent|
      u, movement, pos = ent.components
      ent_id = ent.id

      dir = movement.target_vec - pos.to_vec
      move = dir.unit * dt * speed
      pos.x += move.x
      pos.y += move.y

      # TODO detect crossover of target point
      if (movement.target_vec - pos.to_vec).magnitude < 3
        pos.x = movement.target_vec.x
        pos.y = movement.target_vec.y
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
    'W' => vec(1,0),
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
            # TODO check player permissions on this unit
            # TODO figure out if the dir is allowed
            ent = entity_manager.find_by_id(uid, Unit, Position)
            u, pos = ent.components
            u.status = :moving
            tile_size = 64
            target = pos.to_vec + DIR_VECS[cmd['dir']]*tile_size

            entity_manager.add_component(id: uid, 
                                         component: MovementCommand.new(target_vec: target) )
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

