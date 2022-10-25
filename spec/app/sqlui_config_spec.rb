# frozen_string_literal: true

require 'tempfile'

require_relative '../spec_helper'
require_relative '../../app/sqlui_config'

describe SqluiConfig do
  after { file.unlink }

  let(:sqlui_config) { SqluiConfig.new(file.path) }
  let(:file) do
    file = Tempfile.new('config')
    file.write(config)
    file.rewind
    file
  end
  let(:list_url_path) { '/some/path' }
  let(:url_path) { '/db/path' }
  let(:saved_path) { 'path/to/sql' }
  let(:config) do
    <<~YAML
      name: some server name
      list_url_path: #{list_url_path}
      databases:
        a_database:
          display_name: some database name
          description:  some description
          url_path:     #{url_path}
          saved_path:   #{saved_path}
          client_params:
            database:     some_database
            username:     some_username
            password:     some_password
            host:         some_host
            port:         999
    YAML
  end

  describe '.initialize' do
    subject { sqlui_config }

    context 'when input is valid' do
      it 'returns the expected config' do
        expect(subject.name).to eq('some server name')
        expect(subject.list_url_path).to eq(list_url_path)
        expect(subject.databases.size).to eq(1)
        expect(subject.databases.first.display_name).to eq('some database name')
        expect(subject.databases.first.description).to eq('some description')
        expect(subject.databases.first.url_path).to eq(url_path)
        expect(subject.databases.first.saved_path).to eq(saved_path)
        expect(subject.databases.first.client_params[:database]).to eq('some_database')
        expect(subject.databases.first.client_params[:username]).to eq('some_username')
        expect(subject.databases.first.client_params[:password]).to eq('some_password')
        expect(subject.databases.first.client_params[:host]).to eq('some_host')
        expect(subject.databases.first.client_params[:port]).to eq(999)
      end
    end

    context 'when list_url_path does not start with a /' do
      let(:list_url_path) { 'db/path' }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'list_url_path should start with a /')
      end
    end

    context 'when list_url_path ends with a /' do
      let(:list_url_path) { '/db/path/' }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'list_url_path should not end with a /')
      end
    end

    context 'when list_url_path is only a /' do
      let(:list_url_path) { '/' }

      it "doesn't raise" do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#database_config_for' do
    subject { sqlui_config.database_config_for(url_path: lookup_url_path) }

    context 'when path exists' do
      let(:lookup_url_path) { url_path }

      it 'returns the expected database config' do
        expect(subject.display_name).to eq('some database name')
        expect(subject.description).to eq('some description')
        expect(subject.url_path).to eq(url_path)
        expect(subject.saved_path).to eq(saved_path)
        expect(subject.client_params[:database]).to eq('some_database')
        expect(subject.client_params[:username]).to eq('some_username')
        expect(subject.client_params[:password]).to eq('some_password')
        expect(subject.client_params[:host]).to eq('some_host')
        expect(subject.client_params[:port]).to eq(999)
      end
    end
  end
end
