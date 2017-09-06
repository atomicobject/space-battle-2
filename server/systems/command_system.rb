class CommandSystem
  def update(entity_manager, dt, input, res)
    msgs = input[:messages]
    if msgs
      msgs.each do |msg|
        msg_data = msg.data
        next unless msg_data
        cmds = msg_data['commands'] || []
        map_info = entity_manager.first(MapInfo).get(MapInfo)
        cmds.each do |cmd|
          raw_c = cmd['command']
          next unless raw_c
          c = raw_c.upcase
          uid = cmd['unit']
          player_info = entity_manager.query(
            Q.must(PlayerOwned).with(id: msg.connection_id).
            must(PlayerInfo)).first.components.last
          player_info.total_commands += 1

          if c == 'MOVE'
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned)
            player_info.invalid_commands += 1 if ent.nil?
            next unless ent


            u, pos, owner = ent.components

            if owner.id == msg.connection_id
              dir = RtsGame::DIR_VECS[cmd['dir']]
              if dir.nil?
                u.status = :idle
                u.dirty = true
                puts "Invalid MOVE DIR #{dir} for unit #{uid} from player #{msg.connection_id}"
                player_info.invalid_commands += 1
                next
              end

              target_tile_x = pos.tile_x + dir.x
              target_tile_y = pos.tile_y + dir.y
              target = vec(target_tile_x, target_tile_y)*RtsGame::TILE_SIZE

              if MapInfoHelper.blocked?(map_info, target_tile_x, target_tile_y) || 
                u.status == :moving || u.status == :dead || entity_manager.find_by_id(uid, MovementCommand)
                player_info.invalid_commands += 1
              else
                entity_manager.add_component(id: uid, 
                  component: MovementCommand.new(target_vec: target) )
              end
            end

          elsif c == 'CREATE'
            type = cmd['type']
            unless type && info = RtsGame::UNITS[type.to_sym]
              player_info.invalid_commands += 1
              next
            end

            base_ent = entity_manager.find(Base, Unit, PlayerOwned).
              select{|ent| ent.get(PlayerOwned).id == msg.connection_id}.first

            if base_ent.nil? || base_ent.get(Unit).status != :idle
              player_info.invalid_commands += 1
            else
              entity_manager.add_component(id: base_ent.id, 
                component: CreateCommand.new(type: type.to_sym, build_time: info[:create_time]) )
            end

          elsif c == 'IDENTIFY'
            name, uid = cmd.values_at('name','unit')
            ent = nil
            if uid
              ent = entity_manager.find_by_id(uid, Unit, PlayerOwned, Label)
            else
              ent = entity_manager.find(Base, Unit, PlayerOwned, Label).
                select{|ent| ent.get(PlayerOwned).id == msg.connection_id}.first
              name = "#{name} (#{msg.connection_id})"
            end
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end
            ent.get(Label).text = name

          elsif c == 'SHOOT'
            dx, dy, uid = cmd.values_at('dx','dy','unit')
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned, Attack)
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end

            u, pos, owner = ent.components
            if owner.id == msg.connection_id && u.status == :idle
              entity_manager.add_component(id: uid, component: ShootCommand.new(id: uid, dx: dx, dy: dy))
            else
              player_info.invalid_commands += 1
            end

          elsif c == 'MELEE'
            target, uid = cmd.values_at('target','unit')
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned, Attack)
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end

            u, pos, owner = ent.components
            if owner.id == msg.connection_id && u.status == :idle
              entity_manager.add_component(id: uid, component: MeleeCommand.new(id: uid, target: target))
            else
              player_info.invalid_commands += 1
            end

          elsif c == 'GATHER'
            ent = entity_manager.find_by_id(uid, Unit, Position, ResourceCarrier, PlayerOwned)
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end

            u, pos, res_car, owner = ent.components
            if owner.id == msg.connection_id && u.status == :idle
              unless res_car.resource == 0
                player_info.invalid_commands += 1
                next
              end

              dir = RtsGame::DIR_VECS[cmd['dir']]
              if dir.nil?
                u.status = :idle
                u.dirty = true
                puts "Invalid HARVEST DIR #{dir} for unit #{uid} from player #{msg.connection_id}"
                player_info.invalid_commands += 1
                next
              end
              target_tile_x = pos.tile_x + dir.x
              target_tile_y = pos.tile_y + dir.y

              res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
              if res_info.nil?
                player_info.invalid_commands += 1
              else
                tile_infos =  {} 
                entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
                  player, tile_info = ent.components
                  tile_infos[player.id] = tile_info
                end
                tile_infos.values.each do |tile_info|
                  TileInfoHelper.dirty_tile(tile_info, target_tile_x, target_tile_y)
                end

                resource_ent = entity_manager.find_by_id(res_info[:id], Resource, Label)
                resource = resource_ent.get(Resource)

                resource.total -= resource.value
                resource_ent.get(Label).text = "#{resource.total}"

                res_car.resource = resource.value
                u.dirty = true
                u.status = :idle
                
                res_image = res_car.resource > 10 ? :large_res1 : :small_res1
                entity_manager.add_component(id: uid, component: Decorated.new(image: res_image, scale: 0.3, offset: vec(10, -10)))

                sound = SoundEffectEvent.new(sound_to_play: [:harvest_sound1, :harvest_sound2].sample)
                entity_manager.add_component(id: uid, component: sound)

                if resource.total <= 0
                  MapInfoHelper.remove_resource_at(map_info, target_tile_x, target_tile_y)
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
