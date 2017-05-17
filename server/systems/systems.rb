require_relative 'command_system'
require_relative 'movement_system'
require_relative 'attack_system'

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
          timer.ttl = 0
          if timer.event
            event_comp = timer.event.is_a?(Class) ? timer.event.new : timer.event
            entity_manager.add_component component: event_comp, id: ent_id
          end
          if timer.repeat
            timer.expires_at = current_time_ms + timer.total
          elsif !timer.keep
            entity_manager.remove_component(klass: timer.class, id: ent_id)
          end
        else
          timer.ttl -= delta
        end
      else
        timer.expires_at = current_time_ms + timer.total
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

