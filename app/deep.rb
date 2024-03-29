# frozen_string_literal: true

require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/deep_dup'

# Deep extensions for Hash.
class Hash
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
end
