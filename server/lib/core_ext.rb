class Time
  def to_ms
    (self.to_f * 1000.0).to_i
  end
end
module Enumerable
  def sum
    size > 0 ? inject(0, &:+) : 0
  end
end

class Object
  # def deep_clone
  #   return @deep_cloning_obj if @deep_cloning
  #   @deep_cloning_obj = clone
  #   @deep_cloning_obj.instance_variables.each do |var|
  #     val = @deep_cloning_obj.instance_variable_get(var)
  #     begin
  #       @deep_cloning = true
  #       val = val.deep_clone
  #     rescue TypeError => ex
  #       next
  #     ensure
  #       @deep_cloning = false
  #     end
  #     @deep_cloning_obj.instance_variable_set(var, val)
  #   end
  #   deep_cloning_obj = @deep_cloning_obj
  #   @deep_cloning_obj = nil
  #   deep_cloning_obj
  # end

#   def deep_clone(cache={})
#     return cache[self] if cache.key?(self)
#
#     return self if self.is_a? Class
#     copy =
#       if self.is_a? Hash
#         h = Hash.new#(&default_proc)
#         keys.each do |k|
#           h[k.deep_clone(cache)] = self[k].deep_clone(cache)
#         end
#         h
#       else
#         begin
#           clone()
#         rescue TypeError
#           self
#         end
#       end
#
#     cache[self] = copy
#
#     copy.instance_variables.each do |var|
#       val = instance_variable_get(var)
#       begin
#         val = val.deep_clone(cache)
#       rescue TypeError
#         next
#       end
#       copy.instance_variable_set(var, val)
#     end
#
#     return copy
#   end
  def deep_clone
    # does not work for Hashes with default procs
    Marshal.load( Marshal.dump(self) )
  end

end
