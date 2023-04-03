# frozen_string_literal: true

# Some argument check methods.
module Checks
  def check_non_nil(hash)
    hash.each do |key, value|
      raise "invalid #{key}: #{value.nil? ? 'nil' : value}" if value.nil?
    end

    hash.size == 1 ? hash.values.first : hash.values
  end

  def check_is_a(hash)
    hash.each do |key, (clazz, value)|
      raise "invalid #{key} #{clazz}: #{value.nil? ? 'nil' : value} (#{value.class})" unless value.is_a?(clazz)
    end

    hash.size == 1 ? hash.values.first[1] : hash.values.map { |(_clazz, value)| value }
  end

  def check_boolean(hash)
    hash.each do |key, value|
      raise "invalid #{key}: #{value.nil? ? 'nil' : value}" unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end

    hash.size == 1 ? hash.values.first : hash.values
  end

  def check_non_empty_string(hash)
    hash.each do |key, value|
      raise "invalid #{key}: #{value.nil? ? 'nil' : value}" unless value.is_a?(String) && !value.empty?
    end

    hash.size == 1 ? hash.values.first : hash.values
  end

  def check_positive_integer(hash)
    hash.each do |key, value|
      raise "invalid #{key}: #{value.nil? ? 'nil' : value}" unless value.is_a?(Integer) && value.positive?
    end

    hash.size == 1 ? hash.values.first : hash.values
  end

  def check_enumerable_of(enumerable, clazz)
    check_is_a(enumerable: [Enumerable, enumerable])
    enumerable.each { |value| check_is_a(value: [clazz, value]) }
  end
end
