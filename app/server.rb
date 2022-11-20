# frozen_string_literal: true

require 'base64'
require 'csv'
require 'erb'
require 'json'
require 'sinatra/base'
require 'uri'
require 'webrick/log'
require_relative 'database_metadata'
require_relative 'mysql_types'
require_relative 'sql_parser'
require_relative 'sqlui'

# SQLUI Sinatra server.
class Server < Sinatra::Base
  def self.init_and_run(config, resources_dir)
    Mysql2::Client.default_query_options[:as] = :array
    Mysql2::Client.default_query_options[:cast_booleans] = true
    Mysql2::Client.default_query_options[:database_timezone] = :utc
    Mysql2::Client.default_query_options[:cache_rows] = false

    set :logging,         true
    set :bind,            '0.0.0.0'
    set :port,            config.port
    set :environment,     config.environment
    set :raise_errors,    false
    set :show_exceptions, false

    logger = WEBrick::Log.new

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
        headers 'Content-Type' => 'text/css; charset=utf-8'
        body @css
      end

      get "#{database.url_path}/sqlui.js" do
        @js ||= File.read(File.join(resources_dir, 'sqlui.js'))
        status 200
        headers 'Content-Type' => 'text/javascript; charset=utf-8'
        body @js
      end

      post "#{database.url_path}/metadata" do
        metadata = database.with_client do |client|
          {
            server: "#{config.name} - #{database.display_name}",
            list_url_path: config.list_url_path,
            schemas: DatabaseMetadata.lookup(client, database),
            table_aliases: database.table_aliases,
            joins: database.joins,
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
        headers 'Content-Type' => 'application/json; charset=utf-8'
        body metadata.to_json
      end

      post "#{database.url_path}/query" do
        params.merge!(JSON.parse(request.body.read, symbolize_names: true))
        break client_error('missing sql') unless params[:sql]

        variables = params[:variables] || {}
        sql = find_selected_query(params[:sql], params[:selection])

        result = database.with_client do |client|
          query_result = execute_query(client, variables, sql)
          # NOTE: the call to result.field_types must go before other interaction with the result. Otherwise you will
          # get a seg fault. Seems to be a bug in Mysql2.
          # TODO: stream this and render results on the client as they are returned?
          {
            columns: query_result.fields,
            column_types: MysqlTypes.map_to_google_charts_types(query_result.field_types),
            total_rows: query_result.size,
            rows: (query_result.to_a || []).take(Sqlui::MAX_ROWS)
          }
        end

        result[:selection] = params[:selection]
        result[:query] = params[:sql]

        status 200
        headers 'Content-Type' => 'application/json; charset=utf-8'
        body result.to_json
      end

      get "#{database.url_path}/download_csv" do
        break client_error('missing sql') unless params[:sql]

        sql = Base64.decode64(params[:sql]).force_encoding('UTF-8')
        logger.info "sql: #{sql}"
        variables = params.map { |k, v| k[0] == '_' ? [k, v] : nil }.compact.to_h
        sql = find_selected_query(sql, params[:selection])
        logger.info "sql: #{sql}"

        content_type 'application/csv; charset=utf-8'
        attachment 'result.csv'
        status 200

        database.with_client do |client|
          query_result = execute_query(client, variables, sql)
          stream do |out|
            out << CSV::Row.new(query_result.fields, query_result.fields, header_row: true).to_s.strip
            query_result.each do |row|
              out << "\n#{CSV::Row.new(query_result.fields, row).to_s.strip}"
            end
          end
        end
      end

      get(%r{#{Regexp.escape(database.url_path)}/(query|graph|structure|saved)}) do
        @html ||= File.read(File.join(resources_dir, 'sqlui.html'))
        status 200
        headers 'Content-Type' => 'text/html; charset=utf-8'
        body @html
      end
    end

    error do |e|
      status 500
      headers 'Content-Type' => 'application/json; charset=utf-8'
      message = e.message.lines.first&.strip || 'unexpected error'
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
    headers 'Content-Type' => 'application/json; charset=utf-8'
    body({ error: message, stacktrace: stacktrace }.compact.to_json)
  end

  def find_selected_query(full_sql, selection)
    return full_sql unless selection

    if selection.include?('-')
      # sort because the selection could be in either direction
      selection = selection.split('-').map { |v| Integer(v) }.sort
    else
      selection = Integer(selection)
      selection = [selection, selection]
    end

    if selection[0] == selection[1]
      SqlParser.find_statement_at_cursor(full_sql, selection[0])
    else
      full_sql[selection[0], selection[1]]
    end
  end

  def execute_query(client, variables, sql)
    variables.each do |name, value|
      client.query("SET @#{name} = #{value};")
    end
    queries = if sql.include?(';')
                sql.split(/(?<=;)/).map(&:strip).reject(&:empty?)
              else
                [sql]
              end
    queries.map { |current| client.query(current) }.last
  end
end
