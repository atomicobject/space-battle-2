require 'rspec'
require_relative '../rts'

describe Unit do
  it 'can be built from json' do
    u = Unit.from_json(id: 'monkey')
    expect(u.id).to eq('monkey')
  end
end
