# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/deep'

describe 'deep' do
  describe '#deep_set' do
    subject { target.deep_set(*path, value: value) }

    context 'when the path references a top level key' do
      let(:target) { { a: 1 } }
      let(:path) { [:a] }
      let(:value) { 2 }

      it 'returns the value' do
        expect(subject).to equal(value)
      end

      it 'sets the value' do
        subject
        expect(target[:a]).to eq(value)
      end
    end

    context 'when the path references a nested key' do
      let(:target) { { a: { b: 2 } } }
      let(:path) { %i[a b] }
      let(:value) { 3 }

      it 'returns the value' do
        expect(subject).to equal(value)
      end

      it 'sets the value' do
        subject
        expect(target[:a][:b]).to eq(value)
      end
    end

    context 'when the path references a new key' do
      let(:target) { { a: {} } }
      let(:path) { %i[a b] }
      let(:value) { 4 }

      it 'returns the value' do
        expect(subject).to equal(value)
      end

      it 'sets the value' do
        subject
        expect(target[:a][:b]).to eq(value)
      end
    end

    context 'when the path is empty' do
      subject { target.deep_set(value: value) }
      let(:target) { { a: 1 } }
      let(:value) { 2 }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'no path specified')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: 1 })
      end
    end

    context 'when the path is invalid' do
      subject { target.deep_set(*path, value: value) }
      let(:target) { { a: {} } }
      let(:path) { %i[a b c] }
      let(:value) { 2 }

      it 'raises' do
        expect { subject }.to raise_error(KeyError, 'key not found: b')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: {} })
      end
    end

    context 'when the path references a value which is not a hash' do
      subject { target.deep_set(*path, value: value) }
      let(:target) { { a: { b: 1 } } }
      let(:path) { %i[a b c] }
      let(:value) { 2 }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'value for key is not a hash: b')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: { b: 1 } })
      end
    end
  end

  describe '#deep_delete' do
    subject { target.deep_delete(*path) }

    context 'when the path references a top level key' do
      let(:target) { { a: 1 } }
      let(:path) { [:a] }

      it 'returns the value' do
        expect(subject).to equal(1)
      end

      it 'deletes the value' do
        subject
        expect(target.key?(:a)).to eq(false)
      end
    end

    context 'when the path references a nested key' do
      let(:target) { { a: { b: 2 } } }
      let(:path) { %i[a b] }

      it 'returns the value' do
        expect(subject).to equal(2)
      end

      it 'deletes the value' do
        subject
        expect(target[:a].key?(:b)).to eq(false)
      end
    end

    context 'when the path is empty' do
      subject { target.deep_delete }
      let(:target) { { a: 1 } }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'no path specified')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: 1 })
      end
    end

    context 'when the path is invalid' do
      subject { target.deep_delete(*path) }
      let(:target) { { a: {} } }
      let(:path) { %i[a b c] }

      it 'raises' do
        expect { subject }.to raise_error(KeyError, 'key not found: b')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: {} })
      end
    end

    context 'when the path references a value which is not a hash' do
      subject { target.deep_delete(*path) }
      let(:target) { { a: { b: 1 } } }
      let(:path) { %i[a b c] }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'value for key is not a hash: b')
      end

      it 'does not modify the hash' do
        begin
          subject
        rescue StandardError
          nil
        end
        expect(target).to eq({ a: { b: 1 } })
      end
    end
  end
end
