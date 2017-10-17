class SoundSystem
  DEBOUNCE_UPDATES = 30
  def update(entity_manager, dt, input, res)
    @debounce_map ||= Hash.new{|h,k|h[k] = 0}

    entity_manager.each_entity SoundEffectEvent do |rec|
      ent_id = rec.id
      effect = rec.get(SoundEffectEvent)
      entity_manager.remove_component klass: effect.class, id: ent_id
      if res
        if @debounce_map[effect.sound_to_play] <= 0
          @debounce_map[effect.sound_to_play] = DEBOUNCE_UPDATES
          sample = res[:sounds][effect.sound_to_play]
          sample.play if sample
        end

      end
    end

    @debounce_map.keys.each do |sound|
      @debounce_map[sound] = [@debounce_map[sound]-1,0].max
    end

    if res
      music_info = entity_manager.find(MusicInfo).first.get(MusicInfo)
      if music_info.mood == :peace
        music = res[:music][music_info.peace]
        return unless music
        unless music&.playing?
          music_info.peace = music_info.peace_music.sample
          music = res[:music][music_info.peace]
          music.volume = 0.2
          music.play(true) 
        end

        music = res[:music][music_info.battle]
        music.stop if music&.playing?
      else
        music = res[:music][music_info.battle]
        return unless music
        music.volume = 0.2
        music.play(true) unless music&.playing?

        music = res[:music][music_info.peace]
        music.stop if music&.playing?
      end
    end
  end
end
