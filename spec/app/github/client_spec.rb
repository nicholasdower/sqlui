# frozen_string_literal: true

require_relative '../../../app/github/client'
require_relative '../../spec_helper'

class TestResponse < String
  attr_accessor :code

  def initialize(string, code)
    super(string)
    @code = code
  end
end

describe Github::Client do
  let(:client) { Github::Client.new(access_token: access_token) }
  let(:access_token) { 'some token' }

  describe '#get' do
    subject { client.get(url) }

    let(:url) { 'some_url' }
    let(:response) { TestResponse.new('{ "foo": "bar" }', code) }

    before do
      allow(RestClient).to receive(:get).and_return(response)
    end

    context 'when the response code is 200' do
      let(:code) { 200 }

      it 'returns the response as a Hash' do
        expect(subject).to eq({ 'foo' => 'bar' })
      end
    end

    context 'when the response code is not 200' do
      let(:code) { 500 }

      it 'raises' do
        expect { subject }.to raise_error(StandardError, /GET some_url returned 500, expected 200:/)
      end
    end

    context 'when the response is not valie JSON' do
      let(:code) { 200 }
      let(:response) { TestResponse.new('foo', code) }

      it 'raises' do
        expect { subject }.to raise_error(JSON::ParserError, "unexpected token at 'foo'")
      end
    end
  end
end
