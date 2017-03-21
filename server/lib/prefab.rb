module Prefab
  include Gosu

  def self.base(entity_manager:,x:,y:,player_id:)
    entity_manager.add_entity Unit.new, Base.new, Position.new(x:x, y:y), PlayerOwned.new(id: player_id), Sprited.new(image: :base1)
  end

  def self.map(entity_manager:, resources:)
    base(entity_manager: entity_manager, x: 1984, y: 300, player_id: 0)
  end

end
