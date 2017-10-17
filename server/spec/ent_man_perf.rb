require 'benchmark'
require_relative '../lib/entity_manager'


class Position
end

class Tag
end

em = EntityManager.new
n = 100_000
n.times do
  em.add_entity(Position.new)
end

Benchmark.bm do |x|
  x.report('add same components') do
    n.times do
      em.add_entity(Position.new)
    end
  end

  em.clear!
  n.times do
    em.add_entity(Position.new)
  end

  x.report('add difference components') do
    n.times do
      em.add_entity(Tag.new)
    end
  end

  em.clear!
  n.times do
    em.add_entity(Position.new)
  end

  x.report("simple must") do
    n.times do
      em.query(Q.must(Position))
    end
  end

  x.report("must - maybe") do
    n.times do
      em.query(Q.must(Position).maybe(Tag))
    end
  end

  x.report("multi must") do
    n.times do
      em.query(Q.must(Position).must(Tag))
    end
  end

  x.report("adding after queries") do
    n.times do
      em.add_entity(Tag.new, Position.new)
    end
  end

end

