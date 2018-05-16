class UnitHelper
  def self.update_status(unit, status)
    if unit.status != :dead# && unit.status != status # TODO: find places where we use this but need to set dirty
      unit.status = status
      unit.dirty = true
    end
  end
end
