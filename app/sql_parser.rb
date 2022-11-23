# frozen_string_literal: true

require 'strscan'

# Used to parse strings containing one or more SQL statements.
class SqlParser
  def self.find_statement_at_cursor(sql, cursor)
    parts_with_ranges = parse(sql)
    part_with_range = parts_with_ranges.find do |current|
      cursor >= current[1] && cursor <= current[2]
    end || parts_with_ranges[-1]
    part_with_range[0]
  end

  def self.parse(sql)
    scanner = StringScanner.new(sql)
    statements = []
    single_quoted = false
    double_quoted = false
    single_commented = false
    multi_commented = false
    escaped = false
    current = ''
    start = 0
    until scanner.eos?
      current ||= ''
      char = scanner.getch
      current += char

      if (single_quoted || double_quoted) && !escaped && char == "'" && scanner.peek(1) == "'"
        current += scanner.getch
      elsif escaped
        escaped = false
      elsif !single_quoted && !double_quoted && !escaped && !single_commented && char == '/' && scanner.peek(1) == '*'
        current += scanner.getch
        multi_commented = true
      elsif multi_commented && char == '*' && scanner.peek(1) == '/'
        multi_commented = false
      elsif multi_commented
        next
      elsif !single_quoted && !double_quoted && !escaped && !multi_commented &&
            char == '-' && scanner.peek(1).match?(/-[ \n\t]/)
        current += scanner.getch
        single_commented = true
      elsif !single_quoted && !double_quoted && !escaped && !multi_commented && char == '#'
        single_commented = true
      elsif single_commented && char == "\n"
        single_commented = false
      elsif single_commented
        single_quoted = false if char == "\n"
      elsif char == '\\'
        escaped = true
      elsif char == "'"
        single_quoted = !single_quoted unless double_quoted
      elsif char == '"'
        double_quoted = !double_quoted unless single_quoted
      elsif char == ';' && !single_quoted && !double_quoted
        # Include trailing whitespace if it runs to end of line
        current += scanner.scan(/[ \t]*(?=\n)/) || ''

        # Include an optional trailing single line comma
        current += scanner.scan(/[ \t]*--[ \t][^\n]*/) || ''
        current += scanner.scan(/[ \t]*#[^\n]*/) || ''

        # Include any following blank lines, careful to avoid the final newline in case it is the start of a new query
        while (more = scanner.scan(/\n[ \t]*(?=\n)/))
          current += more
        end

        # Include remaining whitespace if that's all that's left
        if scanner.rest_size == scanner.match?(/[ \t\n]*/)
          current += scanner.rest
          scanner.terminate
        end
        statements << [current, start, scanner.pos]
        start = scanner.pos
        current = nil
      end
    end
    statements << [current, start, scanner.pos] unless current.nil?
    statements
  end
end
