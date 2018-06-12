class CommandSystem
  MOVE_CMD = "MOVE"
  IDENTIFY_CMD = "IDENTIFY"
  CREATE_CMD = "CREATE"
  MELEE_CMD = "MELEE"
  SHOOT_CMD = "SHOOT"
  GATHER_CMD = "GATHER"
  DROP_CMD = "DROP"

  COMMANDS = [
    MOVE_CMD,
    IDENTIFY_CMD,
    CREATE_CMD,
    MELEE_CMD,
    SHOOT_CMD,
    GATHER_CMD,
    DROP_CMD,
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
                UnitHelper.update_status u, :idle
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
            component = GatherSystem.build_command(msg.connection_id, entity_manager, cmd)
            if component
              entity_manager.add_component(id: cmd['unit'], component: component)
            else
              player_info.invalid_commands += 1
            end
          elsif c == DROP_CMD
            component = DropSystem.build_command(msg.connection_id, entity_manager, cmd)
            if component
              entity_manager.add_component(id: cmd['unit'], component: component)
            else
              player_info.invalid_commands += 1
            end
          end

        end
      end
    end
  end
end
