require 'oj'
require 'set'
require 'forwardable'
module ECS
  class EntityStore
    attr_reader :num_entities, :id_to_comp
    def initialize
      clear!
    end

    def deep_clone
      # NOTE! does not work for Hashes with default procs
      if _iterating?
        raise "AHH! EM is still iterating!!" 
      else
        em = Marshal.load( Marshal.dump(self) )
        em
      end
    end

    def warn(msg)
      puts "WARNING: #{Time.now} #{msg}"
    end

    def clear!
      @comp_to_id = {}
      @id_to_comp = {}
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
      rec = build_record(id, @id_to_comp[id], klasses) unless components.any?(&:nil?)
      if block_given?
        yield rec
      else
        rec
      end
    end

    def musts(*klasses)
      raise "specify at least one component" if klasses.empty?
      q = Q
      klasses.each{|k| q = q.must(k)}
      result = query(q)
      query(q)
    end
    alias find musts

    def query(q)
      # TODO cache results as q with content based cache
      #   invalidate cache based on queried_comps
      cache_hit = @cache[q]
      return cache_hit if cache_hit

      queried_comps = q.components
      required_comps = q.required_components

      required_comps.each do |k|
        @comp_to_id[k] ||= []
      end

      id_collection = @comp_to_id.values_at(*required_comps)
      intersecting_ids = id_collection.sort_by(&:size).inject &:&

      recs = intersecting_ids.
        select{|eid| q.matches?(eid, @id_to_comp[eid]) }.
        map do |eid|
          build_record eid, @id_to_comp[eid], queried_comps
        end
      result = QueryResultSet.new(records: recs, ids: recs.map(&:id))

      @cache[q] = result
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

      raise "Cannot add component twice! #{component} -> #{id}" if ent_record.has_key? klass
      ent_record[klass] = component

      @cache.each do |q, results|
        # TODO make results a smart result set that knows about ids to avoid the linear scan
        # will musts vs maybes help here?
        comp_klasses = q.components
        if comp_klasses.include?(klass)
          unless results.has_id?(id)
            results << build_record(id, ent_record, comp_klasses) if q.matches?(id, ent_record)
          end
        end
      end
      nil
    end

    def _remove_component(klass:, id:)
      @comp_to_id[klass] ||= []
      @comp_to_id[klass].delete id
      @id_to_comp[id] ||= {}
      @id_to_comp[id].delete klass

      @cache.each do |q, results|
        comp_klasses = q.components
        if comp_klasses.include?(klass)
          results.delete_if{|res| res.id == id} if results.has_id?(id) && !q.matches?(id, @id_to_comp[id])
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
          results.delete_if{|res| id == res.id} if results.has_id? id
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

    def build_record(*args)
      EntityQueryResult.new(*args)
    end 

    class QueryResultSet
      def initialize(records:, ids:)
        @records = records
        @ids = Set.new(ids)
      end
      def <<(rec)
        @ids << rec.id
        @records << rec
      end
      def has_id?(id)
        @ids.include? id
      end
      def delete_if(&blk)
        rec = @records.find(&blk)
        @records.delete rec
        @ids.delete(rec&.id)
        rec
      end
      def each
        @records.each do |rec|
          yield rec
        end
      end
      extend Forwardable
      def_delegators :@records, :first, :any?, :size, :select, :find, :empty?, :first

    end

    class EntityQueryResult
      attr_reader :id
      def initialize(id, components, queried_components)
        @id = id
        @components = components
        @queried_components = queried_components
      end

      def get(klass)
        @components[klass]
      end

      def components
        @queried_components.map{|qc| @components[qc]}
      end
    end
  end

  class Condition
    attr_reader :k, :attr_conditions
    def initialize(k)
      @attr_conditions = {}
      @k = k
    end

    def ==(other)
      @k == other.k &&
        @attr_conditions.size == other.attr_conditions.size &&
        @attr_conditions.all?{|ac,v| other.attr_conditions[ac] == v}
    end
    alias eql? ==
    def hash
      @_hash ||= @k.hash ^ @attr_conditions.hash
    end

    def components
      @k
    end

    def attrs_match?(id, comps)
      comp = comps[@k]
      @attr_conditions.all? do |name, cond|
        val = comp.send(name) 
        if cond.respond_to? :call
          cond.call val
        else
          val == cond
        end
      end
    end

    def merge_conditions(attrs)
      @attr_conditions ||= {}
      @attr_conditions.merge! attrs
    end
  end

  class Must < Condition
    def matches?(id, comps)
      comps.keys.include?(@k) && attrs_match?(id, comps)
    end
  end

  class Maybe < Condition
    def matches?(id, comps)
      attrs_match?(id, comps)
    end

  end

  class Query
    attr_reader :components, :musts, :maybes
    def self.must(*args)
      Query.new.must(*args)
    end
    def self.maybe(*args)
      Query.new.maybe(*args)
    end

    def initialize
      @components = []
    end

    def must(k)
      @musts ||= []
      @last_condition = Must.new(k)
      @musts << @last_condition
      @components << k
      self
    end

    def required_components
      @musts.flat_map(&:components).uniq
    end

    def with(attr_map)
      @last_condition.merge_conditions(attr_map)
      self
    end

    def maybe(k)
      @maybes ||= []
      @last_condition = Maybe.new(k)
      @maybes << @last_condition
      @components << k
      self
    end

    def matches?(eid, comps)
      @musts.all?{|m| m.matches?(eid, comps)} # ignore maybes  ;)
    end

    def ==(other)
      self.musts == other.musts && self.maybes == other.maybes
    end
    alias eql? ==
    def hash
      @_hash ||= self.musts.hash ^ self.maybes.hash
    end
  end
end
Q = ECS::Query
EntityManager = ECS::EntityStore


