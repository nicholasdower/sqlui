# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/database_config'

describe DatabaseConfig do
  let(:database_config) { DatabaseConfig.new(config_hash) }
  let(:config_hash) do
    {
      display_name: 'some display name',
      description: 'some description',
      url_path: '/some/path',
      saved_path: 'path/to/sql',
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
      it 'returns the expected config' do
        expect(subject.display_name).to eq('some display name')
        expect(subject.description).to eq('some description')
        expect(subject.url_path).to eq('/some/path')
        expect(subject.saved_path).to eq('path/to/sql')
        expect(subject.client_params[:database]).to eq('some_database')
        expect(subject.client_params[:username]).to eq('some_username')
        expect(subject.client_params[:password]).to eq('some_password')
        expect(subject.client_params[:host]).to eq('some_host')
        expect(subject.client_params[:port]).to eq(999)
      end
    end

    context 'url_path slashes' do
      context 'when url_path does not start with a /' do
        before { config_hash[:url_path] = 'db/path' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'url_path should start with a /')
        end
      end

      context 'when url_path ends with a /' do
        before { config_hash[:url_path] = '/db/path/' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'url_path should not end with a /')
        end
      end

      context 'when url_path is only a /' do
        before { config_hash[:url_path] = '/' }

        it 'returns the expected config' do
          expect(subject.url_path).to eq('/')
        end
      end
    end

    shared_examples_for 'a required string field' do |field, example_value|
      context field do
        context "when #{field} is null" do
          before { config_hash[field] = nil }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{field} null")
          end
        end

        context "when #{field} is missing" do
          before { config_hash.delete(field) }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{field} missing")
          end
        end

        context "when #{field} is not a string" do
          before { config_hash[field] = 3 }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{field} not a string")
          end
        end

        context "when #{field} is empty" do
          before { config_hash[field] = ' ' }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "required parameter #{field} empty")
          end
        end

        context "when #{field} has leading and trailing whitespace" do
          before { config_hash[field] = "  #{example_value}  " }

          it 'strips the value' do
            expect(subject.send(field)).to eq(example_value)
          end
        end
      end
    end

    include_examples 'a required string field', :display_name, 'some display name'
    include_examples 'a required string field', :description, 'some description'
    include_examples 'a required string field', :url_path, '/some/url/path'
    include_examples 'a required string field', :saved_path, 'some/saved/path'

    context 'client_params' do
      context 'when client_params is null' do
        before { config_hash[:client_params] = nil }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'required parameter client_params null')
        end
      end

      context 'when client_params is missing' do
        before { config_hash.delete(:client_params) }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'required parameter client_params missing')
        end
      end

      context 'when client_params is not a hash' do
        before { config_hash[:client_params] = 'foo' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'required parameter client_params not a hash')
        end
      end

      context 'when client_params is empty' do
        before { config_hash[:client_params] = {} }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'required parameter client_params empty')
        end
      end
    end
  end

  describe '#with_client' do
    subject { database_config.with_client(&block) }

    let(:client) { instance_double(Mysql2::Client) }

    before do
      allow(Mysql2::Client).to receive(:new).with(config_hash[:client_params]).and_return(client)
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
