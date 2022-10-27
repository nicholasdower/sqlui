# frozen_string_literal: true

require 'erb'
require 'json'
require 'sinatra/base'
require 'uri'
require_relative 'database_metadata'
require_relative 'environment'
require_relative 'mysql_types'
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

  # Connect to each database to verify each can be connected to.
  CONFIG.database_configs.each { |database| database.with_client { |client| client } }

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

  get "#{CONFIG.list_url_path}/?" do
    erb :databases, locals: { config: @config }
  end

  CONFIG.database_configs.each do |database|
    get database.url_path.to_s do
      redirect "#{database.url_path}/app", 301
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
      database_config = @config.database_config_for(url_path: database.url_path)
      metadata = database_config.with_client do |client|
        {
          server: @config.name,
          schemas: DatabaseMetadata.lookup(client, database_config),
          saved: Dir.glob("#{database_config.saved_path}/*.sql").map do |path|
            comment_lines = File.readlines(path).take_while do |l|
              l.start_with?('--')
            end
            description = comment_lines.map { |l| l.sub(/^-- */, '') }.join
            {
              filename: File.basename(path),
              description: description
            }
          end
        }
      end
      status 200
      headers 'Content-Type': 'application/json'
      body metadata.to_json
    end

    get "#{database.url_path}/query_file" do
      break client_error('missing file param') unless params[:file]
      break client_error('no such file') unless File.exist?(params[:file])

      database_config = @config.database_config_for(url_path: database.url_path)
      sql = File.read(File.join(database_config.saved_path, params[:file]))
      result = database_config.with_client do |client|
        execute_query(client, sql).tap { |r| r[:file] = params[:file] }
      end

      status 200
      headers 'Content-Type': 'application/json'
      body result.to_json
    end

    post "#{database.url_path}/query" do
      params.merge!(JSON.parse(request.body.read, symbolize_names: true))
      break client_error('missing sql') unless params[:sql]
      break client_error('missing cursor') unless params[:cursor]

      sql = SqlParser.find_statement_at_cursor(params[:sql], Integer(params[:cursor]))
      raise "can't find query at cursor" unless sql

      database_config = @config.database_config_for(url_path: database.url_path)
      result = database_config.with_client do |client|
        execute_query(client, sql)
      end

      status 200
      headers 'Content-Type': 'application/json'
      body result.to_json
    end
  end

  private

  def client_error(message, stacktrace: nil)
    status(400)
    headers('Content-Type': 'application/json')
    body({ error: message, stacktrace: stacktrace }.compact.to_json)
  end

  def execute_query(client, sql)
    result = client.query(sql)
    # NOTE: the call to result.field_types must go before any other interaction with the result. Otherwise you will
    # get a seg fault. Seems to be a bug in Mysql2.
    column_types = MysqlTypes.map_to_google_charts_types(result.field_types)
    rows = result.map(&:values)
    {
      query: sql,
      columns: result.first&.keys || [],
      column_types: column_types,
      total_rows: rows.size,
      rows: rows.take(MAX_ROWS)
    }
  end

  run!
end
