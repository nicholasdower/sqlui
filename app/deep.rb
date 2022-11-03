# frozen_string_literal: true

# Deep extensions for Enumerable.
module Enumerable
  def deep_transform_keys!(&block)
    each { |value| value.deep_transform_keys!(&block) if value.respond_to?(:deep_transform_keys!) }
    self
  end

  def deep_symbolize_keys!
    deep_transform_keys!(&:to_sym)
  end

  def deep_dup(result = {})
    map do |value|
      value.respond_to?(:deep_dup) ? value.deep_dup : value.clone
    end
    result
  end
end

# Deep extensions for Hash.
class Hash
  def deep_transform_keys!(&block)
    transform_keys!(&block)
    each_value { |value| value.deep_transform_keys!(&block) if value.respond_to?(:deep_transform_keys!) }
    self
  end

  def deep_symbolize_keys!
    deep_transform_keys!(&:to_sym)
  end

  def deep_dup(result = {})
    each do |key, value|
      result[key] = value.respond_to?(:deep_dup) ? value.deep_dup : value.clone
    end
    result
  end

  def deep_set(*path, value:)
    raise ArgumentError, 'no path specified' if path.empty?

    if path.size == 1
      self[path[0]] = value
    else
      raise KeyError, "key not found: #{path[0]}" unless key?(path[0])
      raise ArgumentError, "value for key is not a hash: #{path[0]}" unless self.[](path[0]).is_a?(Hash)

      self.[](path[0]).deep_set(*path[1..], value: value)
    end
  end

  def deep_delete(*path)
    raise ArgumentError, 'no path specified' if path.empty?
    raise KeyError, "key not found: #{path[0]}" unless key?(path[0])

    if path.size == 1
      delete(path[0])
    else
      raise ArgumentError, "value for key is not a hash: #{path[0]}" unless self.[](path[0]).is_a?(Hash)

      self.[](path[0]).deep_delete(*path[1..])
    end
  end

  def deep_merge!(hash)
    hash.each do |key, value|
      if self[key].is_a?(Hash) && value.is_a?(Hash)
        self[key].deep_merge!(value)
      else
        self[key] = value
      end
    end
    self
  end
end
