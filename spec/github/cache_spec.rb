# frozen_string_literal: true

require 'timecop'

require_relative '../../app/github/cache'
require_relative '../spec_helper'

describe Github::Cache do
  before { Timecop.freeze }

  after { Timecop.return }

  let(:hash) { {} }
  let(:cache) { described_class.new(hash) }
  let(:key) { :foo }
  let(:age) { 10 }
  let(:value) { Github::Cache::Entry.new('some_value', age) }

  describe '[]' do
    subject { cache[key] }

    context 'when the value is cached' do
      before { cache[key] = value }

      context 'when the value has not expired' do
        before { Timecop.travel(Time.now + age - 1) }

        it 'returns the value' do
          expect(subject).to eq(value)
        end
      end

      context 'when the value has expired' do
        before { Timecop.travel(Time.now + age) }

        it 'returns nil' do
          expect(subject).to eq(nil)
        end
      end
    end

    context 'when the value is not cached' do
      before { cache[key] = value }

      it 'returns the value' do
        expect(subject).to eq(value)
      end
    end
  end

  describe '[]=' do
    subject { cache[key] = value }

    context 'when the value has not already been cached' do
      it 'sets the cached value' do
        expect(cache[key]).to eq(nil)
        subject
        expect(cache[key]).to eq(value)
      end
    end

    context 'when the value has already been cached' do
      let(:old_value) { Github::Cache::Entry.new('old_value', age) }

      before { cache[key] = old_value }

      it 'replaces the cached value' do
        expect(cache[key]).to eq(old_value)
        subject
        expect(cache[key]).to eq(value)
      end
    end
  end
end
