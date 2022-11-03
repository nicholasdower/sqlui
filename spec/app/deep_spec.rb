# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/deep'

describe 'deep' do
  describe '#deep_merge!' do
    subject { target.deep_merge!(override) }

    let(:target) { { a: { c: 'c' }, d: 2 } }
    let(:override) { { a: { b: 'b' }, d: 3 } }

    it 'merges' do
      expect(subject).to eq({ a: { b: 'b', c: 'c' }, d: 3 })
    end
  end

  describe '#deep_transform_keys!' do
    subject { target.deep_transform_keys!(&transform) }

    let(:transform) { proc { |v| v.to_s } }

    context 'when target is a hash' do
      context 'when the hash is empty' do
        let(:target) { {} }

        it 'returns the hash' do
          expect(subject).to equal(target)
        end

        it 'does not modify the hash' do
          expect(target).to eq({})
        end
      end

      context 'when the hash has non-transformable values' do
        let(:target) { { a: 1, b: 2 } }

        it 'returns the hash' do
          expect(subject).to equal(target)
        end

        it 'transforms the keys' do
          expect(target).to eq({ a: 1, b: 2 })
        end
      end

      context 'when the hash has transformable values' do
        let(:target) do
          {
            a: 1,
            b: {
              c: [1, 2, 3],
              d: [4, { e: 5 }]
            }
          }
        end

        it 'returns the hash' do
          expect(subject).to equal(target)
        end

        it 'transforms the nested keys' do
          expect(target).to eq(
            {
              a: 1,
              b: {
                c: [1, 2, 3],
                d: [4, { e: 5 }]
              }
            }
          )
        end
      end
    end
  end

  describe '#deep_dup' do
    subject { target.deep_dup }

    context 'when target is a hash' do
      context 'when the hash has non-dupable values' do
        let(:target) { { a: 1, b: String.new('foo') } } # mutable string

        it 'returns a new hash' do
          expect(subject).not_to equal(target)
          subject[:a] = 2
          expect(target[:a]).to eq(1)
        end

        it 'clones non-dupable values' do
          subject[:b][0] = 'b'
          expect(subject[:b]).to eq('boo')
          expect(target[:b]).to eq('foo')
        end

        it 'does not modify the hash' do
          expect(target).to eq({ a: 1, b: 'foo' })
        end
      end

      context 'when the hash has dupable values' do
        let(:target) do
          {
            a: 1,
            b: {
              c: [1, 2, 3],
              d: [4, { e: 5 }]
            }
          }
        end

        it 'dups the nested values' do
          expect(target).to eq(
            {
              a: 1,
              b: {
                c: [1, 2, 3],
                d: [4, { e: 5 }]
              }
            }
          )
          subject[:b][:d][:e] = 6
          expect(target[:b][:d][1][:e]).to eq(5)
        end
      end
    end
  end

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
