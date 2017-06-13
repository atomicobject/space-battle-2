require 'rspec'
require_relative "../lib/vec"
require_relative "../lib/core_ext"
require_relative "../lib/entity_manager"
require_relative "../components/components"


describe "EntityManager duplicating" do
  it 'creates an isolated entity manager' do
    em = EntityManager.new
    p1 = Position.new(x:1,y:1)
    em.add_entity(p1, ResourceCarrier.new)
    rec = em.first(Position, ResourceCarrier)
    p2 = Position.new(x:2,y:2)
    em.add_entity(p2, ResourceCarrier.new)
    em.each_entity(Position, ResourceCarrier) {}

    dup_em = em.deep_clone
    # dup_em.clear_cache! #hrm

    dup_rec = dup_em.first(Position, ResourceCarrier)
    dup_em.each_entity(Position, ResourceCarrier) {}

    expect(em).not_to be(dup_em)
    expect(rec).not_to be(dup_rec)

    expect(rec.get(Position)).not_to be(dup_rec.get(Position))
    expect(rec.get(Position).x).to eq(1)
    expect(rec.get(Position).y).to eq(1)
    dup_rec.get(Position).x = 5
    expect(rec.get(Position).x).to eq(1)
  end

  it 'can dup a hash' do
    sub_hash = {x: :y}
    orig = {sub: sub_hash}

    dup = orig.deep_clone

    expect(dup).not_to be(orig)

    orig[:sub][:a] = :b
    expect(dup[:sub][:x]).to be(:y)
    expect(dup[:sub][:a]).not_to be(:b)
  end

  it 'can dup a ivar w/ array of hashes' do
    things = [{id: 3}, {id: 12}]
    o = Object.new
    o.instance_variable_set('@things', things)

    clone = o.deep_clone
    expect(clone.instance_variable_get('@things')[0][:id]).to eq(3)
  end

end

