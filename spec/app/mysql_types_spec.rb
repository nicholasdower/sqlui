# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/mysql_types'

describe MysqlTypes do
  describe '.map_to_google_charts_types' do
    subject { MysqlTypes.map_to_google_charts_types(types) }

    context 'when no types are specified' do
      let(:types) { [] }

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when types without params are specified' do
      let(:types) { %w[int varchar] }

      it 'returns the expected mapped types' do
        expect(subject).to eq(%w[number string])
      end
    end

    context 'when types with params are specified' do
      let(:types) { %w[int varchar(255] }

      it 'returns the expected mapped types' do
        expect(subject).to eq(%w[number string])
      end
    end

    context 'when specified types contain whitespace' do
      let(:types) { [' int ', '  varchar(255] '] }

      it 'returns the expected mapped types' do
        expect(subject).to eq(%w[number string])
      end
    end

    context 'when an unknown type is specified' do
      let(:types) { %w[int varchar foo] }

      it 'returns string as a default' do
        expect(subject).to eq(%w[number string string])
      end
    end
  end
end
