# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/sql_parser'

describe SqlParser do
  describe '.find_statement_at_cursor' do
    subject { SqlParser.find_statement_at_cursor(sql, cursor) }

    context 'when input contains only one query' do
      let(:sql) do
        <<~SQL
          select * from characters;
        SQL
      end

      context 'and cursor is at the beginning' do
        let(:cursor) { 0 }

        it 'returns the only query' do
          expect(subject).to eq('select * from characters;')
        end
      end

      context 'and cursor is at the end' do
        let(:cursor) { sql.length }

        it 'returns the only query' do
          expect(subject).to eq('select * from characters;')
        end
      end

      context 'and cursor is outside the bounds' do
        let(:cursor) { sql.length + 1 }

        it 'returns the only query' do
          expect(subject).to eq('select * from characters;')
        end
      end
    end

    context 'when input contains two queries' do
      let(:query_one) { 'select * from characters limit 1;' }
      let(:query_two) { 'select * from characters limit 2;' }
      let(:sql) do
        <<~SQL
          #{query_one}

          #{query_two}
        SQL
      end

      context 'and cursor is at the beginning of the first query' do
        let(:cursor) { 0 }

        it 'returns the first query' do
          expect(subject).to eq(query_one)
        end
      end

      context 'and cursor is in the middle of the second query' do
        let(:cursor) { 3 }

        it 'returns the second query' do
          expect(subject).to eq(query_one)
        end
      end

      context 'and cursor is at the end of the first query' do
        let(:cursor) { query_one.length }

        it 'returns the first query' do
          expect(subject).to eq(query_one)
        end
      end

      context 'and cursor is at the beginning of the second query' do
        let(:cursor) { query_one.length + 2 }

        it 'returns the first query' do
          expect(subject).to eq(query_two)
        end
      end

      context 'and cursor is in the middle of the second query' do
        let(:cursor) { sql.length - 3 }

        it 'returns the second query' do
          expect(subject).to eq(query_two)
        end
      end

      context 'and cursor is at the end' do
        let(:cursor) { sql.length }

        it 'returns the second query' do
          expect(subject).to eq(query_two)
        end
      end

      context 'and cursor is outside the bounds' do
        let(:cursor) { sql.length + 1 }

        it 'returns the second query' do
          expect(subject).to eq(query_two)
        end
      end
    end
  end
end
