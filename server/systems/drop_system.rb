# NOTES:
# pick up all dropped resources as a small (bucket brigade is still feasible)
# pick up needs to pick up min(remainder, value)
# drop needs to check for units in the way
#   is there a race condition w/ movement here?
# make sure newly created resources are serialized down to the clients
# write unit/intengration tests for this system!!
# performance benchmark this and gather system (significant slow down observed from moving out of command system)
# update docs for drop command
# is there any minimap caching that needs to be invalidated by new resources?
# make sure you can't gather if you're already carrying (should already work that way)
# should dead units drop their resources?
  # will have to place on nears cell that doesn't have a unit on it
class DropSystem
  def self.build_command(connection_id, entity_manager, cmd)
    return nil unless cmd['value']
    ent = entity_manager.find_by_id(cmd['unit'], DropCommand)
    return nil if ent

    ent = entity_manager.find_by_id(cmd['unit'], Unit, Position, ResourceCarrier, PlayerOwned)
    return nil unless ent

    u, pos, res_car, owner = ent.components
    if owner.id == connection_id && u.status == :idle
      return nil if res_car.resource == 0

      dir = RtsGame::DIR_VECS[cmd['dir']]
      if dir.nil?
        UnitHelper.update_status u, :idle
        puts "Invalid DROP DIR #{dir} for unit #{ent.id} from player #{connection_id}"
        return nil
      else
        target_tile_x = pos.tile_x + dir.x
        target_tile_y = pos.tile_y + dir.y
        map_info = entity_manager.first(MapInfo).get(MapInfo)

        return nil unless MapInfoHelper.droppable_at?(map_info, target_tile_x, target_tile_y)
        return DropCommand.new(id: cmd['unit'], dir: cmd['dir'], value: cmd['value'])
      end
    end

    nil
  end

  def update(entity_manager, dt, input, res)
    ts = RtsGame::TILE_SIZE
    new_resources = {}
    map_info = entity_manager.first(MapInfo).get(MapInfo)

    entity_manager.each_entity(Unit, DropCommand, Position, ResourceCarrier, PlayerOwned) do |ent|
      u, cmd, pos, res_car, player = ent.components
      entity_manager.remove_component klass: DropCommand, id: ent.id
      next if u.status == :dead
      dir = RtsGame::DIR_VECS[cmd.dir]
      target_tile_x = pos.tile_x + dir.x
      target_tile_y = pos.tile_y + dir.y

      next unless MapInfoHelper.droppable_at?(map_info, target_tile_x, target_tile_y)

      amount_to_drop = [cmd.value, res_car.resource].min

      res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
      if res_info.nil?
        Prefab.dropped_resource(entity_manager: entity_manager, x:target_tile_x*ts, y:target_tile_y*ts, map_info: map_info, value: 0)
        res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
      end

      tile_infos =  {} 
      entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
        player, tile_info = ent.components
        tile_infos[player.id] = tile_info
      end
      tile_infos.values.each do |tile_info|
        TileInfoHelper.dirty_tile(tile_info, target_tile_x, target_tile_y)
      end

      resource_ent = entity_manager.find_by_id(res_info[:id], Resource, Label)
      if resource_ent
        resource = resource_ent.get(Resource)
        resource.total += amount_to_drop
        resource_ent.get(Label).text = "#{resource.total}"
      else
        new_resources[res_info[:id]] ||= 0
        new_resources[res_info[:id]] += amount_to_drop
      end




      res_car.resource -= amount_to_drop
      UnitHelper.update_status u, :idle

      res_image = res_car.resource > 10 ? :large_res1 : :small_res1
      if res_car.resource == 0
        entity_manager.remove_component(klass: Decorated, id: ent.id)
      end

      # sound = SoundEffectEvent.new(sound_to_play: [:harvest_sound1, :harvest_sound2].sample)
      # entity_manager.add_component(id: ent.id, component: sound) if !entity_manager.find_by_id(ent.id, SoundEffectEvent)
    end

    entity_manager.each_entity Unit, Position, ResourceCarrier do |rec|
      u, pos, res_car = rec.components
      next unless u.status == :dead && res_car.resource > 0

      amount_to_drop = res_car.resource
      if amount_to_drop > 0
        target_tile_x = pos.tile_x
        target_tile_y = pos.tile_y

        res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
        if res_info.nil?
          Prefab.dropped_resource(entity_manager: entity_manager, x:target_tile_x*ts, y:target_tile_y*ts, map_info: map_info, value: 0)
          res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
        end

        tile_infos =  {} 
        entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
          player, tile_info = ent.components
          tile_infos[player.id] = tile_info
        end
        tile_infos.values.each do |tile_info|
          TileInfoHelper.dirty_tile(tile_info, target_tile_x, target_tile_y)
        end

        resource_ent = entity_manager.find_by_id(res_info[:id], Resource, Label)
        if resource_ent
          resource = resource_ent.get(Resource)
          resource.total += amount_to_drop
          resource_ent.get(Label).text = "#{resource.total}"
        else
          new_resources[res_info[:id]] ||= 0
          new_resources[res_info[:id]] += amount_to_drop
        end
        res_car.resource = 0
        entity_manager.remove_component(klass: ResourceCarrier, id: rec.id)
      end
    end


    new_resources.each do |id, delta|
      resource_ent = entity_manager.find_by_id(id, Resource, Label)
      if resource_ent
        resource = resource_ent.get(Resource)
        resource.total += delta
        resource_ent.get(Label).text = "#{resource.total}"
      else
        puts "OH NOES"
      end
    end
  end
end

