# frozen_string_literal: true

require 'erb'
require 'json'
require 'sinatra/base'
require 'uri'
require_relative 'database_metadata'
require_relative 'mysql_types'
require_relative 'sql_parser'
require_relative 'sqlui'

# SQLUI Sinatra server.
class Server < Sinatra::Base
  def self.init_and_run(config, resources_dir)
    set :logging,         true
    set :bind,            '0.0.0.0'
    set :port,            config.port
    set :environment,     config.environment
    set :raise_errors,    false
    set :show_exceptions, false

    get '/-/health' do
      status 200
      body 'OK'
    end

    get '/?' do
      redirect config.list_url_path, 301
    end

    get "#{config.list_url_path}/?" do
      erb :databases, locals: { config: config }
    end

    config.database_configs.each do |database|
      get "#{database.url_path}/?" do
        redirect "#{database.url_path}/query", 301
      end

      get "#{database.url_path}/sqlui.css" do
        @css ||= File.read(File.join(resources_dir, 'sqlui.css'))
        status 200
        headers 'Content-Type' => 'text/css'
        body @css
      end

      get "#{database.url_path}/sqlui.js" do
        @js ||= File.read(File.join(resources_dir, 'sqlui.js'))
        status 200
        headers 'Content-Type' => 'text/javascript'
        body @js
      end

      post "#{database.url_path}/metadata" do
        metadata = database.with_client do |client|
          {
            server: "#{config.name} - #{database.display_name}",
            list_url_path: config.list_url_path,
            schemas: DatabaseMetadata.lookup(client, database),
            saved: Dir.glob("#{database.saved_path}/*.sql").to_h do |path|
              contents = File.read(path)
              comment_lines = contents.split("\n").take_while do |l|
                l.start_with?('--')
              end
              filename = File.basename(path)
              description = comment_lines.map { |l| l.sub(/^-- */, '') }.join("\n")
              [
                filename,
                {
                  filename: filename,
                  description: description,
                  contents: contents.strip
                }
              ]
            end
          }
        end
        status 200
        headers 'Content-Type' => 'application/json'
        body metadata.to_json
      end

      post "#{database.url_path}/query" do
        params.merge!(JSON.parse(request.body.read, symbolize_names: true))
        break client_error('missing sql') unless params[:sql]

        full_sql = params[:sql]
        sql = params[:sql]
        variables = params[:variables] || {}
        if params[:selection]
          selection = params[:selection]
          if selection.include?('-')
            # sort because the selection could be in either direction
            selection = params[:selection].split('-').map { |v| Integer(v) }.sort
          else
            selection = Integer(selection)
            selection = [selection, selection]
          end

          sql = if selection[0] == selection[1]
                  SqlParser.find_statement_at_cursor(params[:sql], selection[0])
                else
                  full_sql[selection[0], selection[1]]
                end

          break client_error("can't find query at selection") unless sql
        end

        result = database.with_client do |client|
          variables.each do |name, value|
            client.query("SET @#{name} = #{value};")
          end
          execute_query(client, sql)
        end

        result[:selection] = params[:selection]
        result[:query] = full_sql

        status 200
        headers 'Content-Type' => 'application/json'
        body result.to_json
      end

      get(%r{#{Regexp.escape(database.url_path)}/(query|graph|structure|saved)}) do
        @html ||= File.read(File.join(resources_dir, 'sqlui.html'))
        status 200
        headers 'Content-Type' => 'text/html'
        body @html
      end
    end

    error do |e|
      status 500
      headers 'Content-Type' => 'application/json'
      message = e.message.lines.first&.strip || 'unexpected error'
      message = "#{message[0..80]}…" if message.length > 80
      result = {
        error: message,
        stacktrace: e.backtrace.map { |b| b }.join("\n")
      }
      body result.to_json
    end

    run!
  end

  private

  def client_error(message, stacktrace: nil)
    status(400)
    headers 'Content-Type' => 'application/json'
    body({ error: message, stacktrace: stacktrace }.compact.to_json)
  end

  def execute_query(client, sql)
    queries = if sql.include?(';')
                sql.split(/(?<=;)/).map(&:strip).reject(&:empty?)
              else
                [sql]
              end
    results = queries.map { |current| client.query(current) }
    result = results[-1]
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
      columns: columns,
      column_types: column_types,
      total_rows: rows.size,
      rows: rows.take(Sqlui::MAX_ROWS)
    }
  end
end
