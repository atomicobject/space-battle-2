class GatherSystem
  # TODO move to prefab?
  def self.build_command(connection_id, entity_manager, cmd)
    ent = entity_manager.find_by_id(cmd['unit'], GatherCommand)
    return nil if ent

    ent = entity_manager.find_by_id(cmd['unit'], Unit, Position, ResourceCarrier, PlayerOwned)
    return nil unless ent

    u, pos, res_car, owner = ent.components
    if owner.id == connection_id && u.status == :idle
      return nil if res_car.resource != 0

      dir = RtsGame::DIR_VECS[cmd['dir']]
      if dir.nil?
        UnitHelper.update_status u, :idle
        puts "Invalid HARVEST DIR #{dir} for unit #{ent.id} from player #{connection_id}"
        return nil
      else
        target_tile_x = pos.tile_x + dir.x
        target_tile_y = pos.tile_y + dir.y
        map_info = entity_manager.first(MapInfo).get(MapInfo)
        res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
        return nil if res_info.nil?

        return GatherCommand.new(id: cmd['unit'], dir: cmd['dir'])
      end
    end

    nil
  end

  def update(entity_manager, dt, input, res)
    entity_manager.each_entity(Unit, GatherCommand, Position, ResourceCarrier, PlayerOwned) do |ent|
      u, cmd, pos, res_car, player = ent.components
      entity_manager.remove_component klass: GatherCommand, id: ent.id
      next if u.status == :dead

      dir = RtsGame::DIR_VECS[cmd.dir]
      target_tile_x = pos.tile_x + dir.x
      target_tile_y = pos.tile_y + dir.y

      map_info = entity_manager.first(MapInfo).get(MapInfo)
      res_info = MapInfoHelper.resource_at(map_info, target_tile_x, target_tile_y)
      if res_info.nil?
        puts "OH NOES! resources ran out?"
      else
        res_id = res_info[:id]
        tile_infos =  {} 
        entity_manager.each_entity(PlayerOwned, TileInfo) do |ent|
          player, tile_info = ent.components
          tile_infos[player.id] = tile_info
        end
        tile_infos.values.each do |tile_info|
          TileInfoHelper.dirty_tile(tile_info, target_tile_x, target_tile_y)
        end

        resource_ent = entity_manager.find_by_id(res_id, Resource, Label)
        resource = resource_ent.get(Resource)

        amount_gathered = [resource.value, resource.total].min
        resource.total -= amount_gathered
        resource_ent.get(Label).text = "#{resource.total}"

        UnitHelper.update_status u, :idle

        base_ent = entity_manager.query(
          Q.must(PlayerOwned).with(id: player.id).
            must(Base).
            must(Unit).
            must(Position)
          ).first
        base_pos = base_ent.get(Position)
        base = base_ent.get(Base)
        if (pos.tile_x-base_pos.tile_x).abs <= 1 && (pos.tile_y-base_pos.tile_y).abs <= 1 
          base.resource += amount_gathered
          player_info = entity_manager.query(Q.must(PlayerOwned).
            with(id: player.id).must(PlayerInfo)).first.components.last
          player_info.total_resources += amount_gathered
          base_ent.get(Unit).dirty = true
        else
          res_car.resource = amount_gathered
          res_image = res_car.resource > 10 ? :large_res1 : :small_res1
          entity_manager.add_component(id: ent.id, component: Decorated.new(image: res_image, scale: 0.3, offset: vec(10, -10))) if !entity_manager.find_by_id(ent.id, Decorated)
        end
        sound = SoundEffectEvent.new(sound_to_play: [:harvest_sound1, :harvest_sound2].sample)
        entity_manager.add_component(id: ent.id, component: sound) if !entity_manager.find_by_id(ent.id, SoundEffectEvent)

        if resource.total <= 0
          entity_manager.remove_entity(id: res_id)
          MapInfoHelper.remove_resource_at(map_info, target_tile_x, target_tile_y)
        end
      end
    end
  end
end

