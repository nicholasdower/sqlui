class Array
  def deep_transform_keys!(&block)
    each { |value| value.deep_transform_keys!(&block) if value.respond_to?(:deep_transform_keys!) }
    self
  end

  def deep_dup(result = {})
    map do |value|
      value.respond_to?(:deep_dup) ? value.deep_dup : value.clone
    end
    result
  end
end
