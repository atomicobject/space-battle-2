require_relative 'command_system'
require_relative 'movement_system'
require_relative 'create_system'
require_relative 'attack_system'
require_relative 'sound_system'

class AnimationSystem
  def initialize(fast_mode:)
    @fast_mode = fast_mode
  end

  def update(entity_manager, dt, input, res)
    # TODO make other properties animatable... opacity, scale?
    entity_manager.each_entity Animated, Sprited do |rec|
      ent_id = rec.id
      animated = rec.get(Animated)
      sprite = rec.get(Sprited)

      animated.time += dt

      frame_timing = animated.timings[animated.frames[animated.index]]
      frame_timing *= 20 if @fast_mode

      if animated.time > frame_timing
        animated.index += 1
        animated.time = 0

        if animated.index > animated.frames.size - 1
          if animated.loop
            animated.index = 0
            sprite.image = animated.frames[animated.index]
          else
            entity_manager.remove_component(klass: Sprited, id: ent_id)
            entity_manager.remove_component(klass: Animated, id: ent_id)
          end
        else
          sprite.image = animated.frames[animated.index]
        end
      end

    end
  end
end

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

class DeathSystem
  def update(entity_manager, delta, input, res)
    entity_manager.each_entity DeathEvent do |rec|
      entity_manager.remove_entity id: rec.id
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