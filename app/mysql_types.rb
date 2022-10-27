# frozen_string_literal: true

# Maps MySQL data types to type descriptions the client can use.
class MysqlTypes
  def initialize
    raise "can't instantiate #{self.class}"
  end

  class << self
    def map_to_google_charts_types(types)
      types.map do |type|
        type.gsub!(/\([^)]*\)/, '').strip!
        case type
        when 'bool', 'boolean'
          'boolean'
        when /double/, 'bigint', 'bit', 'dec', 'decimal', 'float', 'int', 'integer', 'mediumint', 'smallint', 'tinyint'
          'number'
        when /char/, /binary/, /blob/, /text/, 'enum', 'set', /image/
          'string'
        when 'date', 'year'
          'date'
        when 'datetime', 'timestamp'
          'datetime'
        when 'time'
          'timeofday'
        else
          puts "unexpected MySQL type: #{type}"
          'string'
        end
      end
    end
  end
end
