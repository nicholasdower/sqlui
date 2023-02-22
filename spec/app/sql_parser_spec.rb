# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/sql_parser'

def test_find_statement_at_cursor(context:, sql:, cursor:, it:, expected: sql) # rubocop:disable Naming/MethodParameterName
  context context do
    it it do
      expect(SqlParser.find_statement_at_cursor(sql, cursor)).to eq(expected)
    end
  end
end

describe SqlParser do
  describe '.find_statement_at_cursor' do
    context 'when input contains only one query' do
      test_find_statement_at_cursor(
        context: 'and cursor is at the beginning',
        sql: "select * from characters;\n",
        cursor: 0,
        it: 'returns the only query'
      )

      test_find_statement_at_cursor(
        context: 'and cursor is at the end',
        sql: "select * from characters;\n",
        cursor: "select * from characters;\n".length,
        it: 'returns the only query'
      )

      test_find_statement_at_cursor(
        context: 'and cursor is outside the bounds',
        sql: "select * from characters;\n",
        cursor: "select * from characters;\n".length + 1,
        it: 'returns the only query'
      )

      test_find_statement_at_cursor(
        context: 'and cursor is in multiline trailing whitespace',
        sql: "select * from characters; \t \n \t \n \t \n",
        cursor: "select * from characters; \t \n \t".length,
        it: 'returns the only query'
      )
    end

    context 'when input contains two queries' do
      test_find_statement_at_cursor(
        context: 'and cursor is at the beginning of the first query',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: 0,
        it: 'returns the only query',
        expected: 'select * from characters limit 1;'
      )

      test_find_statement_at_cursor(
        context: 'and cursor is in the end of the first query',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1;'.length,
        it: 'returns the first query',
        expected: 'select * from characters limit 1;'
      )

      test_find_statement_at_cursor(
        context: 'and cursor is at the beginning of the second query',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1;'.length + 1,
        it: 'returns the second query',
        expected: "\nselect * from characters limit 2;\n"
      )

      test_find_statement_at_cursor(
        context: 'and cursor is in the middle of the second query',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: 40,
        it: 'returns the second query',
        expected: "\nselect * from characters limit 2;\n"
      )

      test_find_statement_at_cursor(
        context: 'and cursor is at the end',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: "select * from characters limit 1;\nselect * from characters limit 2;\n".length,
        it: 'returns the second query',
        expected: "\nselect * from characters limit 2;\n"
      )

      test_find_statement_at_cursor(
        context: 'and cursor is outside the bounds',
        sql: "select * from characters limit 1;\nselect * from characters limit 2;\n",
        cursor: 1_000,
        it: 'returns the second query',
        expected: "\nselect * from characters limit 2;\n"
      )

      test_find_statement_at_cursor(
        context: 'and cursor is in multiline trailing whitespace after first query',
        sql: "select * from characters limit 1; \t \n \t \nselect * from characters limit 2;\n",
        cursor: "select * from characters limit 1; \t \n".length,
        it: 'returns the first query',
        expected: "select * from characters limit 1; \t \n \t "
      )

      # Bug fix.
      test_find_statement_at_cursor(
        context: 'and cursor is after single line comment containing a quote',
        sql: "select -- Nick's stuff\n2;\nselect 1;\n",
        cursor: "select -- Nick's stuff\n2;\nselect 1;\n".length,
        it: 'returns the second query',
        expected: "\nselect 1;\n"
      )
    end

    context 'when query ends in -- comment' do
      test_find_statement_at_cursor(
        context: 'and cursor at end of comment',
        sql: "select * from characters limit 1; -- foo\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1; -- foo'.length,
        it: 'returns the preceding query',
        expected: 'select * from characters limit 1; -- foo'
      )

      test_find_statement_at_cursor(
        context: 'and cursor on next line',
        sql: "select * from characters limit 1; -- foo\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1; -- foo'.length + 1,
        it: 'returns the preceding query',
        expected: "\nselect * from characters limit 2;\n"
      )

      test_find_statement_at_cursor(
        context: "and comment isn't actually a comment",
        sql: "select * from characters limit 1; --foo\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1; --foo'.length,
        it: 'returns the second statement',
        expected: " --foo\nselect * from characters limit 2;\n"
      )
    end

    context 'when query ends in # comment' do
      test_find_statement_at_cursor(
        context: 'and cursor at end of comment',
        sql: "select * from characters limit 1; # foo\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1; # foo'.length,
        it: 'returns the preceding query',
        expected: 'select * from characters limit 1; # foo'
      )

      test_find_statement_at_cursor(
        context: 'and cursor on next line',
        sql: "select * from characters limit 1; -- foo\nselect * from characters limit 2;\n",
        cursor: 'select * from characters limit 1; -- foo'.length + 1,
        it: 'returns the preceding query',
        expected: "\nselect * from characters limit 2;\n"
      )
    end

    context 'when sql contains a semicolon' do
      test_find_statement_at_cursor(
        context: 'in double quotes',
        sql: 'select ";"; select 2',
        cursor: 0,
        it: 'ignores the semicolon',
        expected: 'select ";";'
      )

      test_find_statement_at_cursor(
        context: 'in single quotes',
        sql: "select ';';",
        cursor: 0,
        it: 'ignores the semicolon',
        expected: "select ';';"
      )

      test_find_statement_at_cursor(
        context: 'in single quotes with escaped quote',
        sql: "select ''';';",
        cursor: 0,
        it: 'ignores the semicolon',
        expected: "select ''';';"
      )

      test_find_statement_at_cursor(
        context: 'in -- comment',
        sql: 'select 1; -- foo; bar',
        cursor: 0,
        it: 'ignores the semicolon',
        expected: 'select 1; -- foo; bar'
      )

      test_find_statement_at_cursor(
        context: 'in # comment',
        sql: 'select 1; # foo; bar',
        cursor: 0,
        it: 'ignores the semicolon',
        expected: 'select 1; # foo; bar'
      )

      test_find_statement_at_cursor(
        context: 'in multi line comment',
        sql: 'select /* foo;bar */1;',
        cursor: 0,
        it: 'ignores the semicolon',
        expected: 'select /* foo;bar */1;'
      )
    end

    test_find_statement_at_cursor(
      context: 'when input contains zero queries',
      sql: "foo\n",
      cursor: 0,
      it: 'returns the input unchanged',
      expected: "foo\n"
    )

    context 'when input contains multiple queries on one line' do
      test_find_statement_at_cursor(
        context: 'and cursor at end of first query',
        sql: "select 1;  select 2\n",
        cursor: 'select 1;'.length,
        it: 'returns the first query',
        expected: 'select 1;'
      )

      test_find_statement_at_cursor(
        context: 'and cursor past end of first query',
        sql: "select 1;  select 2\n",
        cursor: 'select 1;'.length + 1,
        it: 'returns the first query',
        expected: "  select 2\n"
      )

      test_find_statement_at_cursor(
        context: 'and cursor in uncompleted final query',
        sql: "select 1; select\n",
        cursor: 16,
        it: 'returns the uncompleted query',
        expected: " select\n"
      )
    end
  end
end
