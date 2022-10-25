# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/database_config'

describe DatabaseConfig do
  let(:database_config) { DatabaseConfig.new(hash) }
  let(:url_path)     { '/some/path' }
  let(:saved_path)   { 'path/to/sql' }
  let(:hash) do
    {
      display_name: 'some display name',
      description: 'some description',
      url_path: url_path,
      saved_path: saved_path,
      client_params: {
        database: 'some_database',
        username: 'some_username',
        password: 'some_password',
        host: 'some_host',
        port: 999
      }
    }
  end

  describe '.initialize' do
    subject { database_config }

    context 'when input is valid' do
      it "doesn't raise" do
        expect { subject }.not_to raise_error
      end
    end

    context 'when url_path does not start with a /' do
      let(:url_path) { 'db/path' }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'url_path should start with a /')
      end
    end

    context 'when url_path ends with a /' do
      let(:url_path) { '/db/path/' }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'url_path should not end with a /')
      end
    end

    context 'when url_path is only a /' do
      let(:url_path) { '/' }

      it "doesn't raise" do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#with_client' do
    subject { database_config.with_client(&block) }

    let(:client) { instance_double(Mysql2::Client) }

    before do
      allow(Mysql2::Client).to receive(:new).with(hash[:client_params]).and_return(client)
      allow(client).to receive(:close).exactly(1).time
    end

    context 'when the specified block does not raise' do
      let(:block) do
        proc { :some_result }
      end

      it 'returns the result' do
        expect(subject).to equal(:some_result)
      end

      it 'closes the client' do
        expect(client).to receive(:close).exactly(1).time
        subject
      end
    end

    context 'when the specified block raises' do
      let(:block) do
        proc { raise 'some error' }
      end

      it 'raises' do
        expect { subject }.to raise_error(RuntimeError, 'some error')
      end

      it 'closes the client' do
        expect(client).to receive(:close).exactly(1).time
        begin
          subject
        rescue StandardError
          nil
        end
      end
    end
  end
end
