# frozen_string_literal: true

require 'erb'
require 'json'
require 'mysql2'
require 'sinatra/base'
require 'set'
require 'uri'
require 'yaml'
require_relative 'environment'
require_relative 'sql_parser'
require_relative 'sqlui_config'

if ARGV.include?('-v') || ARGV.include?('--version')
  puts File.read('.version')
  exit
end

raise 'you must specify a configuration file' unless ARGV.size == 1
raise 'configuration file does not exist' unless File.exist?(ARGV[0])

# SQLUI Sinatra server.
class Server < Sinatra::Base
  MAX_ROWS = 1_000

  CONFIG = SqluiConfig.new(ARGV[0])

  def initialize(app = nil, **_kwargs)
    super
    @config = Server::CONFIG
    @resources_dir = File.join(File.expand_path('..', File.dirname(__FILE__)), 'client', 'resources')
  end

  set :logging, true
  set :bind,    '0.0.0.0'
  set :port,    Environment.server_port
  set :env,     Environment.server_env

  get '/-/health' do
    status 200
    body 'OK'
  end

  get "#{CONFIG.list_path}/?" do
    erb :databases, locals: { config: @config }
  end

  CONFIG.databases.each do |database|
    get database.url_path.to_s do
      redirect "#{params[:database]}/app", 301
    end

    get "#{database.url_path}/app" do
      @html ||= File.read(File.join(@resources_dir, 'sqlui.html'))
      status 200
      headers 'Content-Type': 'text/html'
      body @html
    end

    get "#{database.url_path}/sqlui.css" do
      @css ||= File.read(File.join(@resources_dir, 'sqlui.css'))
      status 200
      headers 'Content-Type': 'text/css'
      body @css
    end

    get "#{database.url_path}/sqlui.js" do
      @js ||= File.read(File.join(@resources_dir, 'sqlui.js'))
      status 200
      headers 'Content-Type': 'text/javascript'
      body @js
    end

    get "#{database.url_path}/metadata" do
      status 200
      headers 'Content-Type': 'application/json'
      body load_metadata(url_path: database.url_path).to_json
    end

    get "#{database.url_path}/query_file" do
      return client_error('missing file param') unless params[:file]
      return client_error('no such file') unless File.exist?(params[:file])

      database_config = @config.database_config_for(url_path: database.url_path)

      sql = File.read(File.join(database_config.saved_path, params[:file]))
      result = execute_query(database_config.client, sql).tap { |r| r[:file] = params[:file] }

      status 200
      headers 'Content-Type': 'application/json'
      body result.to_json
    end

    post "#{database.url_path}/query" do
      params.merge!(JSON.parse(request.body.read, symbolize_names: true))
      return client_error('missing sql') unless params[:sql]
      return client_error('missing cursor') unless params[:cursor]

      sql = SqlParser.find_statement_at_cursor(params[:sql], Integer(params[:cursor]))
      raise "can't find query at cursor" unless sql

      database_config = @config.database_config_for(url_path: database.url_path)
      result = execute_query(database_config.client, sql)

      status 200
      headers 'Content-Type': 'application/json'
      body result.to_json
    end
  end

  private

  def client_error(message, stacktrace: nil)
    status(400)
    headers('Content-Type': 'application/json')
    body({ message: message, stacktrace: stacktrace }.compact.to_json)
  end

  def load_metadata(url_path:)
    database_config = @config.database_config_for(url_path: url_path)
    result = {
      server: @config.name,
      schemas: {},
      saved: Dir.glob("#{database_config.saved_path}/*.sql").map do |path|
        {
          filename: File.basename(path),
          description: File.readlines(path).take_while { |l| l.start_with?('--') }.map { |l| l.sub(/^-- */, '') }.join
        }
      end
    }

    where_clause = if database_config.database
                     "where table_schema = '#{database_config.database}'"
                   else
                     "where table_schema not in('mysql', 'sys', 'information_schema', 'performance_schema')"
                   end
    column_result = database_config.client.query(
      <<~SQL
        select
          table_schema,
          table_name,
          column_name,
          data_type,
          character_maximum_length,
          is_nullable,
          column_key,
          column_default,
          extra
        from information_schema.columns
        #{where_clause}
        order by table_schema, table_name, column_name, ordinal_position;
    SQL
    )
    column_result.each do |row|
      row = row.transform_keys(&:downcase).transform_keys(&:to_sym)
      table_schema = row[:table_schema]
      unless result[:schemas][table_schema]
        result[:schemas][table_schema] = {
          tables: {}
        }
      end
      table_name = row[:table_name]
      tables = result[:schemas][table_schema][:tables]
      unless tables[table_name]
        tables[table_name] = {
          indexes: {},
          columns: {}
        }
      end
      columns = result[:schemas][table_schema][:tables][table_name][:columns]
      column_name = row[:column_name]
      columns[column_name] = {} unless columns[column_name]
      column = columns[column_name]
      column[:name] = column_name
      column[:data_type] = row[:data_type]
      column[:length] = row[:character_maximum_length]
      column[:allow_null] = row[:is_nullable]
      column[:key] = row[:column_key]
      column[:default] = row[:column_default]
      column[:extra] = row[:extra]
    end

    where_clause = if database_config.database
                     "where table_schema = '#{database_config.database}'"
                   else
                     "where table_schema not in('mysql', 'sys', 'information_schema', 'performance_schema')"
                   end
    stats_result = database_config.client.query(
      <<~SQL
        select
          table_schema,
          table_name,
          index_name,
          seq_in_index,
          non_unique,
          column_name
        from information_schema.statistics
        #{where_clause}
        order by table_schema, table_name, if(index_name = "PRIMARY", 0, index_name), seq_in_index;
    SQL
    )
    stats_result.each do |row|
      row = row.transform_keys(&:downcase).transform_keys(&:to_sym)
      table_schema = row[:table_schema]
      tables = result[:schemas][table_schema][:tables]
      table_name = row[:table_name]
      indexes = tables[table_name][:indexes]
      index_name = row[:index_name]
      indexes[index_name] = {} unless indexes[index_name]
      index = indexes[index_name]
      column_name = row[:column_name]
      index[column_name] = {}
      column = index[column_name]
      column[:name] = index_name
      column[:seq_in_index] = row[:seq_in_index]
      column[:non_unique] = row[:non_unique]
      column[:column_name] = row[:column_name]
    end

    result
  end

  def execute_query(client, sql)
    result = client.query(sql, cast: false)
    rows = result.map(&:values)
    columns = result.first&.keys || []
    # TODO: use field_types
    column_types = columns.map { |_| 'string' }
    unless rows.empty?
      maybe_non_null_column_value_exemplars = columns.each_with_index.map do |_, index|
        row = rows.find do |current|
          !current[index].nil?
        end
        row.nil? ? nil : row[index]
      end
      column_types = maybe_non_null_column_value_exemplars.map do |value|
        case value
        when String, NilClass
          'string'
        when Integer, Float
          'number'
        when Date
          'date'
        when Time
          'datetime'
        when TrueClass, FalseClass
          'boolean'
        else
          # TODO: report an error
          value.class.to_s
        end
      end
    end
    {
      query: sql,
      columns: columns,
      column_types: column_types,
      total_rows: rows.size,
      rows: rows.take(MAX_ROWS)
    }
  end

  run!
end
