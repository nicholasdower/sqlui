# frozen_string_literal: true

require 'tempfile'
require 'yaml'

require_relative '../spec_helper'
require_relative '../../app/deep'
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
  let(:config) do
    config_hash.deep_transform_keys!(&:to_s).to_yaml
  end
  let(:config_hash) do
    {
      name: 'some server name',
      list_url_path: '/some/path',
      databases: {
        database_one: {
          display_name: 'some database name',
          description: 'some description',
          url_path: '/db/path',
          saved_path: 'path/to/sql',
          client_params: {
            database: 'some_database',
            username: 'some_username',
            password: 'some_password',
            host: 'some_host',
            port: 999
          }
        }
      }
    }
  end

  describe '.initialize' do
    subject { sqlui_config }

    context 'when input is valid' do
      context 'when one database is specified' do
        it 'returns the expected config' do
          expect(subject.name).to eq('some server name')
          expect(subject.list_url_path).to eq('/some/path')
          expect(subject.database_configs.size).to eq(1)
          expect(subject.database_configs.first.display_name).to eq('some database name')
          expect(subject.database_configs.first.description).to eq('some description')
          expect(subject.database_configs.first.url_path).to eq('/db/path')
          expect(subject.database_configs.first.saved_path).to eq('path/to/sql')
          expect(subject.database_configs.first.client_params[:database]).to eq('some_database')
          expect(subject.database_configs.first.client_params[:username]).to eq('some_username')
          expect(subject.database_configs.first.client_params[:password]).to eq('some_password')
          expect(subject.database_configs.first.client_params[:host]).to eq('some_host')
          expect(subject.database_configs.first.client_params[:port]).to eq(999)
        end
      end

      context 'when more than one database is specified' do
        before do
          config_hash[:databases][:database_two] = config_hash[:databases][:database_one].deep_dup
          config_hash[:databases][:database_two][:display_name] = 'some other database name'
        end

        it 'returns the expected config' do
          expect(subject.database_configs.first.client_params[:port]).to eq(999)
          expect(subject.database_configs[0].display_name).to eq('some database name')
          expect(subject.database_configs[1].display_name).to eq('some other database name')
        end
      end
    end

    context 'list_url_path slashes' do
      context 'when list_url_path does not start with a /' do
        before { config_hash[:list_url_path] = 'db/path' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'list_url_path should start with a /')
        end
      end

      context 'when list_url_path ends with a /' do
        before { config_hash[:list_url_path] = '/db/path/' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'list_url_path should not end with a /')
        end
      end

      context 'when list_url_path is only a /' do
        before { config_hash[:list_url_path] = '/' }

        it "doesn't raise" do
          expect { subject }.not_to raise_error
        end
      end
    end

    shared_examples_for 'a required string field' do |path, example_value, accessor|
      context path.join(' -> ') do
        context "when #{path.join(' -> ')} is null" do
          before { config_hash.deep_set(*path, value: nil) }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{path[-1]} null")
          end
        end

        context "when #{path.join(' -> ')} is missing" do
          before { config_hash.deep_delete(*path) }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{path[-1]} missing")
          end
        end

        context "when #{path.join(' -> ')} is not a string" do
          before { config_hash.deep_set(*path, value: 3) }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{path[-1]} not a string")
          end
        end

        context "when #{path.join(' -> ')} is empty" do
          before { config_hash.deep_set(*path, value: ' ') }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{path[-1]} empty")
          end
        end

        context "when #{path.join(' -> ')} has leading and trailing whitespace" do
          before { config_hash.deep_set(*path, value: "  #{example_value}  ") }

          it 'strips the value' do
            expect(accessor.call(subject)).to eq(example_value)
          end
        end
      end
    end

    include_examples 'a required string field',
                     [:name],
                     'some name', -> (s) { s.name }
    include_examples 'a required string field',
                     [:list_url_path],
                     '/sqlui', -> (s) { s.list_url_path }
    include_examples 'a required string field',
                     [:databases, :database_one, :display_name],
                     'some display name', -> (s) { s.database_configs[0].display_name }
    include_examples 'a required string field',
                     [:databases, :database_one, :description],
                     'some description', -> (s) { s.database_configs[0].description }
    include_examples 'a required string field',
                     [:databases, :database_one, :url_path],
                     '/sqlui/foo', -> (s) { s.database_configs[0].url_path }
    include_examples 'a required string field',
                     [:databases, :database_one, :saved_path],
                     'some/path', -> (s) { s.database_configs[0].saved_path }

    context 'when config is an erb template' do
      before { config_hash[:list_url_path] = '<%= "/some/template/val" %>' }

      it 'renders the template' do
        expect(subject.list_url_path).to eq('/some/template/val')
      end
    end

    context 'when databases null' do
      before { config_hash[:databases] = nil }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'required parameter databases null')
      end
    end

    context 'when databases not a hash' do
      before { config_hash[:databases] = 'foo' }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'required parameter databases not a hash')
      end
    end

    context 'when databases not specified' do
      before { config_hash.delete(:databases) }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, 'required parameter databases missing')
      end
    end
  end

  describe '#database_config_for' do
    subject { sqlui_config.database_config_for(url_path: url_path) }

    context 'when path exists' do
      let(:url_path) { '/db/path' }

      it 'returns the expected database config' do
        expect(subject.display_name).to eq('some database name')
        expect(subject.description).to eq('some description')
        expect(subject.url_path).to eq('/db/path')
        expect(subject.saved_path).to eq('path/to/sql')
        expect(subject.client_params[:database]).to eq('some_database')
        expect(subject.client_params[:username]).to eq('some_username')
        expect(subject.client_params[:password]).to eq('some_password')
        expect(subject.client_params[:host]).to eq('some_host')
        expect(subject.client_params[:port]).to eq(999)
      end
    end

    context 'when path does not exist' do
      let(:url_path) { '/some/other/path' }

      it 'returns the expected database config' do
        expect { subject }.to raise_error(ArgumentError, 'no config found for path /some/other/path')
      end
    end
  end
end
