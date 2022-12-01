# frozen_string_literal: true

require 'base64'
require 'csv'
require 'erb'
require 'json'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'
require 'sinatra/base'
require 'uri'
require 'webrick'
require_relative 'database_metadata'
require_relative 'mysql_types'
require_relative 'sql_parser'
require_relative 'sqlui'

# SQLUI Sinatra server.
class Server < Sinatra::Base
  def self.logger
    @logger ||= WEBrick::Log.new
  end

  def self.init_and_run(config, resources_dir)
    logger.info("Airbrake enabled: #{config.airbrake[:enabled]}")
    if config.airbrake[:enabled]
      require 'airbrake'
      require 'airbrake/rack'

      Airbrake.configure do |c|
        c.app_version = File.read('.version').strip
        c.environment = config.environment
        c.logger.level = Logger::DEBUG if config.environment != :production?
        config.airbrake.each do |key, value|
          c.send("#{key}=".to_sym, value) unless key == :enabled
        end
      end
      Airbrake.add_filter(Airbrake::Rack::RequestBodyFilter.new)
      Airbrake.add_filter(Airbrake::Rack::HttpParamsFilter.new)
      Airbrake.add_filter(Airbrake::Rack::HttpHeadersFilter.new)
      use Airbrake::Rack::Middleware
    end

    use Rack::Deflater
    use Prometheus::Middleware::Collector
    use Prometheus::Middleware::Exporter

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

    get '/-/health' do
      status 200
      body 'OK'
    end

    get '/?' do
      redirect config.list_url_path, 301
    end

    get '/favicon.svg' do
      send_file File.join(resources_dir, 'favicon.svg')
    end

    get "#{config.list_url_path}/?" do
      erb :databases, locals: { config: config }
    end

    config.database_configs.each do |database|
      get "#{database.url_path}/?" do
        redirect "#{database.url_path}/query", 301
      end

      get "#{database.url_path}/sqlui.css" do
        headers 'Content-Type' => 'text/css; charset=utf-8'
        send_file File.join(resources_dir, 'sqlui.css')
      end

      get "#{database.url_path}/sqlui.js" do
        headers 'Content-Type' => 'text/javascript; charset=utf-8'
        send_file File.join(resources_dir, 'sqlui.js')
      end

      post "#{database.url_path}/metadata" do
        metadata = database.with_client do |client|
          {
            server: "#{config.name} - #{database.display_name}",
            list_url_path: config.list_url_path,
            schemas: DatabaseMetadata.lookup(client, database),
            tables: database.tables,
            columns: database.columns,
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
        data = request.body.read
        request.body.rewind # since Airbrake will read the body on error
        params.merge!(JSON.parse(data, symbolize_names: true))
        break client_error('missing sql') unless params[:sql]

        variables = params[:variables] || {}
        sql = find_selected_query(params[:sql], params[:selection])

        status 200
        headers 'Content-Type' => 'application/json; charset=utf-8'

        database.with_client do |client|
          query_result = execute_query(client, variables, sql)
          stream do |out|
            if query_result
              json = <<~RES.chomp
                {
                  "columns": #{query_result.fields.to_json},
                  "column_types": #{MysqlTypes.map_to_google_charts_types(query_result.field_types).to_json},
                  "total_rows": #{query_result.size.to_json},
                  "selection": #{params[:selection].to_json},
                  "query": #{params[:sql].to_json},
                  "rows": [
              RES
              out << json
              bytes = json.bytesize
              query_result.each_with_index do |row, i|
                json = "#{i.zero? ? '' : ','}\n    #{row.to_json}"
                bytes += json.bytesize
                break if i == Sqlui::MAX_ROWS || bytes > Sqlui::MAX_BYTES

                out << json
              end
              out << <<~RES

                  ]
                }
              RES
            else
              out << <<~RES
                {
                  "columns": [],
                  "column_types": [],
                  "total_rows": 0,
                  "selection": #{params[:selection].to_json},
                  "query": #{params[:sql].to_json},
                  "rows": []
                }
              RES
            end
          end
        end
      end

      get "#{database.url_path}/download_csv" do
        break client_error('missing sql') unless params[:sql]

        sql = Base64.decode64(params[:sql]).force_encoding('UTF-8')
        variables = params.map { |k, v| k[0] == '_' ? [k, v] : nil }.compact.to_h
        sql = find_selected_query(sql, params[:selection])

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
        status 200
        erb :sqlui, locals: {
          environment: config.environment.to_s,
          airbrake_enabled: config.airbrake[:enabled],
          airbrake_project_id: config.airbrake[:project_id],
          airbrake_project_key: config.airbrake[:project_key]
        }
      end
    end

    error 400..510 do
      exception = env['sinatra.error']
      stacktrace = exception&.full_message(highlight: false)
      if request.env['HTTP_ACCEPT'] == 'application/json'
        headers 'Content-Type' => 'application/json; charset=utf-8'
        message = exception&.message&.lines&.first&.strip || 'unexpected error'
        json = { error: message, stacktrace: stacktrace }.compact.to_json
        body json
      else
        message = "#{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
        erb :error, locals: { title: "SQLUI #{message}", message: message, stacktrace: stacktrace }
      end
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
