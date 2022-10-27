# Hash extensions.
class Hash
  def deep_transform_keys!(&block)
    transform_keys!(&:to_s)
    each_value { |value| value.deep_transform_keys!(&block) if value.respond_to?(:deep_transform_keys!) }
    self
  end

  def deep_dup(result = {})
    each do |key, value|
      result[key] = value.respond_to?(:deep_dup) ? value.deep_dup : value.clone
    end
    result
  end

  def deep_set(*path, value:)
    raise ArgumentError('no path specified') if path.empty?
    raise KeyError.new("key not found: #{path[0]}") unless key?(path[0])

    if path.size == 1
      self.[]=(path[0], value)
    else
      raise ArgumentError.new("value at :#{path[0]} is not a hash") unless self.[](path[0]).is_a?(Hash)

      self.[](path[0]).deep_set(*path[1..-1], value: value)
    end
  end

  def deep_delete(*path)
    raise ArgumentError.new('no path specified') if path.empty?
    raise KeyError.new("key not found: #{path[0]}") unless key?(path[0])
    if path.size == 1
      delete(path[0])
    else
      self.[](path[0]).deep_delete(*path[1..-1])
    end
  end
end
