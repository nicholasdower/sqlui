require_relative '../spec_helper'
require_relative '../../app/hash'

describe Hash do
  subject { hash.deep_transform_keys!(&transform) }

  let(:transform) { proc { |v| v.to_s} }

  describe '#deep_transform_keys!' do
    context 'when the hash empty' do
      let(:hash) { {} }

      it 'returns the hash' do
        expect(subject).to equal(hash)
      end

      it 'does not modify the hash' do
        expect(hash).to eq({})
      end
    end

    context 'when the hash has non-hash entries' do
      let(:hash) { {a: 1, b: 2} }

      it 'returns the hash' do
        expect(subject).to equal(hash)
      end

      it 'transforms the keys' do
        expect(hash).to eq({'a': 1, 'b': 2})
      end
    end

    context 'when the hash has hash entries' do
      let(:hash) { {a: 1, b: { c: 3, d: {e: 4}}} }

      it 'returns the hash' do
        expect(subject).to equal(hash)
      end

      it 'transforms the nested keys' do
        expect(hash).to eq({'a': 1, 'b': {'c': 3, 'd': {'e': 4}}})
      end
    end
  end
end
