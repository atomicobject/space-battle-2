class World
  def initialize(systems)
    @systems = systems
  end

  def update(*args)
    @systems.map do |sys|
      sys.update *args
    end
  end

end
