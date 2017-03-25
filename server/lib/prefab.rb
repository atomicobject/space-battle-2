module Prefab
  include Gosu

  def self.base(entity_manager:,x:,y:,player_id:)
    entity_manager.add_entity Unit.new(status: :base), Base.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :base1)
  end

  def self.worker(entity_manager:,x:,y:,player_id:)
    entity_manager.add_entity Unit.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :worker1)
  end

  def self.map(entity_manager:, resources:)
    # TODO load from map
    start_point = vec(200, 200)
    base(entity_manager: entity_manager, x: start_point.x, y: start_point.y, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x + 64, y: start_point.y + 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x - 64, y: start_point.y + 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x + 64, y: start_point.y - 64, player_id: 0)
    worker(entity_manager: entity_manager, x: start_point.x - 64, y: start_point.y - 64, player_id: 0)
  end

end
