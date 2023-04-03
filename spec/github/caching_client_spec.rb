# frozen_string_literal: true

require 'timecop'

require_relative '../../app/github/caching_client'
require_relative '../spec_helper'

describe Github::CachingClient do
  before { Timecop.freeze }

  after { Timecop.return }

  let(:client) { instance_double(Github::Client) }
  let(:cache) { Github::Cache.new({}) }
  let(:caching_client) { described_class.new(client, cache) }

  describe 'get_with_caching' do
    subject { caching_client.get_with_caching(url, cache_for: cache_for) }

    let(:url) { 'some_url' }
    let(:cache_for) { 10 }
    let(:response) do
      { foo: [{ bar: :baz }], moo: { maz: :mop } }
    end

    before do
      allow(client).to receive(:is_a?).and_return(true)
      allow(client).to receive(:get).once.with(url).and_return(response)
    end

    context 'when the response has not already been cached' do
      it 'calls the client' do
        expect(client).to receive(:get).with(url)
        subject
      end

      it 'returns the response' do
        expect(subject).to eq(response)
      end

      it 'dups the response' do
        subject[:foo] = 1
        expect(subject).to eq({ foo: 1, moo: { maz: :mop } })
        expect(response).to eq({ foo: [{ bar: :baz }], moo: { maz: :mop } })
      end
    end

    context 'when the response has already been cached' do
      before do
        caching_client.get_with_caching(url, cache_for: cache_for)
        allow(client).to receive(:get).with(url).once.and_return(next_response)
      end

      let(:next_response) do
        { poo: [{ par: :paz }], noo: { naz: :nop } }
      end

      context 'when the cache entry has not expired' do
        it 'does not call the client' do
          expect(client).not_to receive(:get).with(url)
          subject
        end

        it 'returns the response' do
          expect(subject).to eq(response)
        end

        it 'dups the response' do
          subject[:foo] = 1
          expect(subject).to eq({ foo: 1, moo: { maz: :mop } })
          expect(response).to eq({ foo: [{ bar: :baz }], moo: { maz: :mop } })
        end
      end

      context 'when the cache entry has expired' do
        before do
          Timecop.travel(cache_for)
        end

        it 'calls the client' do
          expect(client).to receive(:get).with(url)
          subject
        end

        it 'returns the response' do
          expect(subject).to eq(next_response)
        end

        it 'dups the response' do
          subject[:poo] = 1
          expect(subject).to eq({ poo: 1, noo: { naz: :nop } })
          expect(next_response).to eq({ poo: [{ par: :paz }], noo: { naz: :nop } })
        end
      end
    end
  end
end
