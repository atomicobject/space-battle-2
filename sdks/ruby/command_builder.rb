class CommandBuilder
  MOVE_COMMAND = 'MOVE'.freeze
  GATHER_COMMAND = 'GATHER'.freeze
  DROP_COMMAND = 'DROP'.freeze
  CREATE_COMMAND = 'CREATE'.freeze
  SHOOT_COMMAND = 'SHOOT'.freeze
  MELEE_COMMAND = 'MELEE'.freeze
  IDENTIFY_COMMAND = 'IDENTIFY'.freeze

  UNIT_TYPES = %w[worker scout tank].freeze

  def self.move(unit, dir)
    { command: MOVE_COMMAND, unit: unit.id, dir: dir }
  end

  def self.gather(unit, dir)
    { command: GATHER_COMMAND, unit: unit.id, dir: dir }
  end

  def self.drop(unit, dir, value)
    { command: DROP_COMMAND, unit: unit.id, dir: dir, value: value }
  end

  def self.create(unit_type)
    raise "invalid unit type: #{unit_type}" unless UNIT_TYPES.include? unit_type
    { command: CREATE_COMMAND, type: unit_type }
  end

  def self.shoot(unit, dx, dy)
    { command: SHOOT_COMMAND, unit: unit, dx: dx, dy: dy }
  end

  def self.melee(unit, target)
    { command: MELEE_COMMAND, unit: unit, target: target}
  end

  def self.identity(unit, name)
    { command: IDENTIFY_COMMAND, unit: unit, name: name}
  end

end
