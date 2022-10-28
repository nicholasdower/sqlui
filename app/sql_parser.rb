# frozen_string_literal: true

# Used to parse strings containing one or more SQL statements.
class SqlParser
  def self.find_statement_at_cursor(sql, cursor)
    return sql unless sql.include?(';')

    parts_with_ranges = []
    sql.scan(/[^;]*;[ \n]*/) { |part| parts_with_ranges << [part, 0, part.size] }
    parts_with_ranges.inject(0) do |pos, current|
      current[1] += pos
      current[2] += pos
    end
    part_with_range = parts_with_ranges.find do |current|
      cursor >= current[1] && cursor < current[2]
    end || parts_with_ranges[-1]
    part_with_range[0].strip
  end
end
