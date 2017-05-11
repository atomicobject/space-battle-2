class EntityManager
  attr_reader :num_entities
  def initialize
    clear!
  end

  def warn(msg)
    puts "WARNING: #{Time.now} #{msg}"
  end

  def clear!
    @comp_to_id = {}#Hash.new {|h, k| h[k] = []}
    @id_to_comp = {}#Hash.new {|h, k| h[k] = {}}
    @cache = {}
    @num_entities = 0

    @iterator_count = 0
    @ents_to_add_later = []
    @comps_to_add_later = []
    @comps_to_remove_later = []
    @ents_to_remove_later = []
  end

  def clear_cache!
    @cache = {}
  end

  def find_by_id(id, *klasses)
    @id_to_comp[id] ||= {}
    ent_record = @id_to_comp[id]
    components = ent_record.values_at(*klasses)
    rec = build_record(id, components) unless components.any?(&:nil?)
    if block_given?
      yield rec
    else
      rec
    end
  end

  # bakes in the assumption that we are an ECS and that rows are joined by id
  def find(*klasses)
    cache_hit = @cache[klasses]
    return cache_hit if cache_hit

    klasses.each do |k|
      @comp_to_id[k] ||= []
    end
    id_collection = @comp_to_id.values_at(*klasses)
    intersecting_ids = id_collection.inject &:&
    result = intersecting_ids.map do |id|
      build_record id, @id_to_comp[id].values_at(*klasses)
    end
    @cache[klasses] = result
    result
  end

  def first(*klasses)
    find(*klasses).first
  end

  def each_entity(*klasses, &blk)
    ents = find(*klasses)
    if block_given?
      _iterating do
        ents.each &blk
      end
    end
    ents
  end

  def remove_component(klass:, id:)
    if _iterating?
      _remove_component_later klass: klass, id: id
    else
      _remove_component klass: klass, id: id
    end
  end

  def add_component(component:,id:)
    if _iterating?
      _add_component_later component: component, id: id
    else
      _add_component component: component, id: id
    end
  end

  def remove_entites(ids:)
    if _iterating?
      _remove_entities_later(ids: ids)
    else
      _remove_entites(ids: ids)
    end
  end

  def remove_entity(id:)
    if _iterating?
      _remove_entity_later(id: id)
    else
      _remove_entity(id: id)
    end
  end

  def add_entity(*components)
    id = generate_id
    if _iterating?
      _add_entity_later(id:id, components: components)
    else
      _add_entity(id: id, components: components)
    end
    id
  end


  private
  def _add_entity_later(id:,components:)
    @ents_to_add_later << {components: components, id: id}
  end
  def _remove_entities_later(ids:)
    ids.each do |id|
      @ents_to_remove_later << {id: id}
    end
  end
  def _remove_entity_later(id:)
    @ents_to_remove_later << {id: id}
  end

  def _remove_component_later(klass:,id:)
    @comps_to_remove_later << {klass: klass, id: id}
  end
  def _add_component_later(component:,id:)
    @comps_to_add_later << {component: component, id: id}
  end

  def _apply_updates
    ids_to_remove = @ents_to_remove_later.map{|e|e[:id]}
    _remove_entites ids: ids_to_remove
    @ents_to_remove_later.clear

    @comps_to_remove_later.each do |opts|
      _remove_component klass: opts[:klass], id: opts[:id]
    end
    @comps_to_remove_later.clear

    @comps_to_add_later.each do |opts|
      _add_component component: opts[:component], id: opts[:id]
    end
    @comps_to_add_later.clear

    @ents_to_add_later.each do |opts|
      _add_entity id: opts[:id], components: opts[:components]
    end
    @ents_to_add_later.clear
  end

  def _iterating
    @iterator_count += 1
    yield
    @iterator_count -= 1
    _apply_updates unless _iterating?
  end

  def _iterating?
    @iterator_count > 0
  end

  def _add_component(component:,id:)
    @comp_to_id[component.class] ||= []
    @comp_to_id[component.class] << id
    @id_to_comp[id] ||= {}
    ent_record = @id_to_comp[id]
    klass = component.class
    ent_record[klass] = component

    @cache.each do |comp_klasses, results|
      if comp_klasses.include?(klass)
        components = ent_record.values_at(*comp_klasses)
        results << build_record(id, components) unless components.any?(&:nil?)
      end
    end
    nil
  end

  def _remove_component(klass:, id:)
    @comp_to_id[klass] ||= []
    @comp_to_id[klass].delete id
    @id_to_comp[id] ||= {}
    @id_to_comp[id].delete klass

    @cache.each do |comp_klasses, results|
      if comp_klasses.include?(klass)
        results.delete_if{|res| res.id == id}
      end
    end
    nil
  end

  def _remove_entites(ids:)
    return if ids.empty?

    @num_entities -= ids.size
    ids.each do |id|
      @id_to_comp.delete(id)
    end

    @comp_to_id.each do |klass, ents|
      ents.delete_if{|ent_id| ids.include? ent_id}
    end

    @cache.each do |comp_klasses, results|
      results.delete_if{|res| ids.include? res.id}
    end
  end

  def _remove_entity(id:)
    if @id_to_comp.delete(id)
      @num_entities -= 1

      @comp_to_id.each do |klass, ents|
        ents.delete(id)
      end

      @cache.each do |comp_klasses, results|
        results.delete_if{|res| id == res.id}
      end
    end
  end

  def _add_entity(id:, components:)
    components.each do |comp|
      add_component component: comp, id: id
    end
    id
  end

  def generate_id
    @num_entities += 1
    @ent_counter ||= 0
    @ent_counter += 1
  end

  def build_record(id, components)
    EntityQueryResult.new(id, components)
  end

  EntityQueryResult = Struct.new(:id, :components) do
    def get(klass)
      components.find{|c|c.class == klass}
    end
  end

end


if $0 == __FILE__
  class Player; end
  class Foo; end
  class Bar; end

  class Position
    def initialize(x:,y:)
    end
  end

  entity_manager = EntityManager.new

  enemy_id = entity_manager.add_entity Position.new(x:4, y:5)
  player_id = entity_manager.add_entity Position.new(x:2, y:3), Player.new


  100_000.times do |i|
    entity_manager.add_entity Position.new(x:4,y:5), Foo.new, Bar.new
  end

  # require 'pry'
  # binding.pry

  require 'benchmark'
  n = 100_000
  Benchmark.bm do |x|
    x.report do
      n.times do |i|
        entity_manager.remove_entity player_id+n
#         if i % 100 == 0
#           entity_manager.add_component component: Player.new, id: player_id+i
#         end
#
#         if i % 100 == 1
#           entity_manager.remove_component klass: Player, id: player_id+i-1
#         end
#
#         if i == n-1
#           entity_manager.remove_entity(player_id)
#         end
#         entity_manager.find(Position, Player)
      end
    end
  end
end
