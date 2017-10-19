class CommandSystem
  MOVE_CMD = "MOVE"
  IDENTIFY_CMD = "IDENTIFY"
  CREATE_CMD = "CREATE"
  MELEE_CMD = "MELEE"
  SHOOT_CMD = "SHOOT"
  GATHER_CMD = "GATHER"

  COMMANDS = [
    MOVE_CMD,
    IDENTIFY_CMD,
    CREATE_CMD,
    MELEE_CMD,
    SHOOT_CMD,
    GATHER_CMD,
  ]
  def update(entity_manager, dt, input, res)
    msgs = input[:messages]
    if msgs
      msgs.each do |msg|
        msg_data = msg.data
        next unless msg_data
        cmds = msg_data['commands']
        return unless cmds
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

          if c == MOVE_CMD
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

          elsif c == CREATE_CMD
            type = cmd['type']
            unless type && info = RtsGame::UNITS[type.to_sym]
              player_info.invalid_commands += 1
              next
            end

            base_ent = entity_manager.query(
              Q.must(PlayerOwned).with(id: msg.connection_id).
                must(Base).must(Unit)).first

            if base_ent.nil? || base_ent.get(Unit).status != :idle || entity_manager.find_by_id(base_ent.id, CreateCommand)
              player_info.invalid_commands += 1
            else
              entity_manager.add_component(id: base_ent.id, 
                component: CreateCommand.new(type: type.to_sym, build_time: info[:create_time]) )
            end

          elsif c == IDENTIFY_CMD
            name, uid = cmd.values_at('name','unit')
            ent = nil
            if uid
              ent = entity_manager.find_by_id(uid, Unit, PlayerOwned, Label)
            else
              name = "#{name} (#{msg.connection_id+1})"
              ent = entity_manager.query(
                Q.must(PlayerOwned).with(id: msg.connection_id).
                  must(Label).
                  must(Named).with(name: "player-name")
                ).first
            end
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end
            ent.get(Label).text = name

          elsif c == SHOOT_CMD
            dx, dy, uid = cmd.values_at('dx','dy','unit')
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned, Attack)
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end

            u, pos, owner = ent.components
            if owner.id == msg.connection_id && u.status == :idle && !entity_manager.find_by_id(uid, ShootCommand)
              entity_manager.add_component(id: uid, component: ShootCommand.new(id: uid, dx: dx, dy: dy))
            else
              player_info.invalid_commands += 1
            end

          elsif c == MELEE_CMD
            target, uid = cmd.values_at('target','unit')
            ent = entity_manager.find_by_id(uid, Unit, Position, PlayerOwned, Attack)
            if ent.nil?
              player_info.invalid_commands += 1
              next
            end

            u, pos, owner = ent.components
            if owner.id == msg.connection_id && u.status == :idle && !entity_manager.find_by_id(uid, MeleeCommand)
              entity_manager.add_component(id: uid, component: MeleeCommand.new(id: uid, target: target))
            else
              player_info.invalid_commands += 1
            end

          elsif c == GATHER_CMD
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

                u.dirty = true
                u.status = :idle

                base_ent = entity_manager.query(
                  Q.must(PlayerOwned).with(id: msg.connection_id).
                    must(Base).
                    must(Unit).
                    must(Position)
                  ).first
                base_pos = base_ent.get(Position)
                base = base_ent.get(Base)
                if (pos.tile_x-base_pos.tile_x).abs <= 1 && (pos.tile_y-base_pos.tile_y).abs <= 1 

                  base.resource += resource.value
                  player_info = entity_manager.query(Q.must(PlayerOwned).
                    with(id: owner.id).must(PlayerInfo)).first.components.last
                  player_info.total_resources += resource.value
                  base_ent.get(Unit).dirty = true
                else
                  res_car.resource = resource.value
                  res_image = res_car.resource > 10 ? :large_res1 : :small_res1
                  entity_manager.add_component(id: uid, component: Decorated.new(image: res_image, scale: 0.3, offset: vec(10, -10))) if !entity_manager.find_by_id(uid, Decorated)
                end
                sound = SoundEffectEvent.new(sound_to_play: [:harvest_sound1, :harvest_sound2].sample)
                entity_manager.add_component(id: uid, component: sound) if !entity_manager.find_by_id(uid, SoundEffectEvent)

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
