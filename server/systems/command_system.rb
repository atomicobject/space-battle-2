class CommandSystem
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
              target = pos.to_vec + RtsGame::DIR_VECS[cmd['dir']]*tile_size

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
              target = pos.to_vec + RtsGame::DIR_VECS[cmd['dir']]*tile_size

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
