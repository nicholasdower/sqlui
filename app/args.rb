# frozen_string_literal: true

# Argument validation.
class Args
  def self.fetch_non_empty_string(hash, key)
    value = fetch_non_nil(hash, key, String)
    raise ArgumentError, "required parameter #{key} empty" if value.strip.empty?

    value
  end

  def self.fetch_non_empty_int(hash, key)
    fetch_non_nil(hash, key, Integer)
  end

  def self.fetch_non_empty_hash(hash, key)
    value = fetch_non_nil(hash, key, Hash)
    raise ArgumentError, "required parameter #{key} empty" if value.empty?

    value
  end

  def self.fetch_non_nil(hash, key, *classes)
    raise ArgumentError, "required parameter #{key} missing" unless hash.key?(key)

    value = hash[key]
    raise ArgumentError, "required parameter #{key} null" if value.nil?

    if classes.size.positive? && !classes.find { |clazz| value.is_a?(clazz) }
      if classes.size != 1
        raise ArgumentError, "required parameter #{key} not #{classes.map(&:to_s).map(&:downcase).join(' or ')}"
      end

      class_name = classes[0].to_s.downcase
      class_name = %w[a e i o u].include?(class_name[0]) ? "an #{class_name}" : "a #{class_name}"
      raise ArgumentError, "required parameter #{key} not #{class_name}"
    end

    value
  end
end
