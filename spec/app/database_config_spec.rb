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

    shared_examples_for 'a string field' do |field, example_value|
      context field do
        context "when #{field} is null" do
          before { config_hash[field] = nil }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "parameter #{field} null")
          end
        end

        context "when #{field} is missing" do
          before { config_hash.delete(field) }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "parameter #{field} missing")
          end
        end

        context "when #{field} is not a string" do
          before { config_hash[field] = 3 }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "parameter #{field} not a string")
          end
        end

        context "when #{field} is empty" do
          before { config_hash[field] = ' ' }

          it 'raises' do
            expect { subject }.to raise_error(ArgumentError, "parameter #{field} empty")
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

    include_examples 'a string field', :display_name, 'some display name'
    include_examples 'a string field', :description, 'some description'
    include_examples 'a string field', :url_path, '/some/url/path'
    include_examples 'a string field', :saved_path, 'some/saved/path'

    context 'client_params' do
      context 'when client_params is null' do
        before { config_hash[:client_params] = nil }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter client_params null')
        end
      end

      context 'when client_params is missing' do
        before { config_hash.delete(:client_params) }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter client_params missing')
        end
      end

      context 'when client_params is not a hash' do
        before { config_hash[:client_params] = 'foo' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter client_params not a hash')
        end
      end

      context 'when client_params is empty' do
        before { config_hash[:client_params] = {} }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter client_params empty')
        end
      end
    end

    context 'columns' do
      before do
        config_hash[:columns] = columns
      end

      context 'when nil' do
        let(:columns) { nil }

        it 'returns an empty hash' do
          expect(subject.columns).to eq({})
        end
      end

      context 'when not a hash' do
        let(:columns) { 'foo' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter columns not a hash')
        end
      end

      context 'when links is not a hash' do
        let(:columns) { { name: { links: 'n' } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'invalid links for name (n), expected array')
        end
      end

      context 'when link short_name is not a string' do
        let(:columns) { { name: { links: { link1: { short_name: 1, long_name: 'l', template: 't' } } } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'invalid link short_name for name link (1), expected string')
        end
      end

      context 'when link long_name is not a string' do
        let(:columns) { { name: { links: { link1: { short_name: 's', long_name: 1, template: 't' } } } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'invalid link long_name for name link (1), expected string')
        end
      end

      context 'when valid' do
        let(:columns) { { name: { links: { link1: { short_name: 's', long_name: 'l', template: 't' } } } } }

        it 'returns the expected links' do
          expect(subject.columns).to eq({ name: { links: [{ long_name: 'l', short_name: 's',
                                                            template: 't' }] } })
        end
      end
    end

    context 'tables' do
      before do
        config_hash[:tables] = tables
      end

      context 'when nil' do
        let(:tables) { nil }

        it 'returns an empty hash' do
          expect(subject.tables).to eq({})
        end
      end

      context 'when not a hash' do
        let(:tables) { 'foo' }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'parameter tables not a hash')
        end
      end

      context 'when alias is a string' do
        let(:tables) { { table: { alias: 'n' } } }

        it 'returns the expected aliases' do
          expect(subject.tables).to eq({ table: { alias: 'n' } })
        end
      end

      context 'when alias is not a string' do
        let(:tables) { { table: { alias: 1 } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'invalid table alias for table (1), expected string')
        end
      end

      context 'when multiple aliases specified' do
        let(:tables) { { table: { alias: 'n' }, other_table: { alias: 'o' } } }

        it 'returns the expected aliases' do
          expect(subject.tables).to eq({ table: { alias: 'n' }, other_table: { alias: 'o' } })
        end
      end

      context 'when duplicate aliases specified' do
        let(:tables) { { table: { alias: 'n' }, other_table: { alias: 'n' } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'duplicate table aliases: n')
        end
      end

      context 'when boost is an int' do
        let(:tables) { { table: { boost: 1 } } }

        it 'returns the expected aliases' do
          expect(subject.tables).to eq({ table: { boost: 1 } })
        end
      end

      context 'when boost is not an int' do
        let(:tables) { { table: { boost: '1' } } }

        it 'raises' do
          expect { subject }.to raise_error(ArgumentError, 'invalid table boost for table (1), expected int')
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
