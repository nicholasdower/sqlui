# frozen_string_literal: true

require 'erb'
require 'json'
require 'sinatra/base'
require 'uri'
require_relative 'database_metadata'
require_relative 'environment'
require_relative 'mysql_types'
require_relative 'sql_parser'
require_relative 'sqlui'

# SQLUI Sinatra server.
class Server < Sinatra::Base
  def self.init_and_run(config, resources_dir)
    set :logging,         true
    set :bind,            '0.0.0.0'
    set :port,            Environment.server_port
    set :env,             Environment.server_env
    set :raise_errors,    false
    set :show_exceptions, false

    get '/-/health' do
      status 200
      body 'OK'
    end

    get "#{config.list_url_path}/?" do
      erb :databases, locals: { config: config }
    end

    config.database_configs.each do |database|
      get database.url_path.to_s do
        redirect "#{database.url_path}/app", 301
      end

      get "#{database.url_path}/app" do
        @html ||= File.read(File.join(resources_dir, 'sqlui.html'))
        status 200
        headers 'Content-Type': 'text/html'
        body @html
      end

      get "#{database.url_path}/sqlui.css" do
        @css ||= File.read(File.join(resources_dir, 'sqlui.css'))
        status 200
        headers 'Content-Type': 'text/css'
        body @css
      end

      get "#{database.url_path}/sqlui.js" do
        @js ||= File.read(File.join(resources_dir, 'sqlui.js'))
        status 200
        headers 'Content-Type': 'text/javascript'
        body @js
      end

      get "#{database.url_path}/metadata" do
        database_config = config.database_config_for(url_path: database.url_path)
        metadata = database_config.with_client do |client|
          {
            server: config.name,
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

        database_config = config.database_config_for(url_path: database.url_path)
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

        sql = params[:sql]
        selection = params[:selection]
        if selection
          selection = selection.split(':').map { |v| Integer(v) }

          sql = if selection[0] == selection[1]
                  SqlParser.find_statement_at_cursor(params[:sql], selection[0])
                else
                  params[:sql][selection[0], selection[1]]
                end
          break client_error("can't find query at selection") unless sql
        end

        database_config = config.database_config_for(url_path: database.url_path)
        result = database_config.with_client do |client|
          execute_query(client, sql)
        end

        result[:selection] = params[:selection]

        status 200
        headers 'Content-Type': 'application/json'
        body result.to_json
      end
    end

    error do |e|
      status 500
      headers 'Content-Type': 'application/json'
      result = {
        error: e.message,
        stacktrace: e.backtrace.map { |b| b }.join("\n")
      }
      body result.to_json
    end

    run!
  end

  private

  def client_error(message, stacktrace: nil)
    status(400)
    headers('Content-Type': 'application/json')
    body({ error: message, stacktrace: stacktrace }.compact.to_json)
  end

  def execute_query(client, sql)
    if sql.include?(';')
      results = sql.split(/(?<=;)/).map { |current| client.query(current) }
      result = results[-1]
    else
      result = client.query(sql)
    end
    # NOTE: the call to result.field_types must go before any other interaction with the result. Otherwise you will
    # get a seg fault. Seems to be a bug in Mysql2.
    if result
      column_types = MysqlTypes.map_to_google_charts_types(result.field_types)
      rows = result.map(&:values)
      columns = result.first&.keys || []
    else
      column_types = []
      rows = []
      columns = []
    end
    {
      query: sql,
      columns: columns,
      column_types: column_types,
      total_rows: rows.size,
      rows: rows.take(Sqlui::MAX_ROWS)
    }
  end
end
