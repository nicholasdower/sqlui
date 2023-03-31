# frozen_string_literal: true

require 'base64'
require 'csv'
require 'digest/md5'
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
require_relative 'version'

# SQLUI Sinatra server.
class Server < Sinatra::Base
  def self.logger
    @logger ||= WEBrick::Log.new
  end

  def self.init_and_run(config, resources_dir)
    logger.info("Starting SQLUI v#{Version::SQLUI}")
    logger.info("Airbrake enabled: #{config.airbrake[:server]&.[](:enabled) || false}")

    WEBrick::HTTPRequest.const_set('MAX_URI_LENGTH', 2 * 1024 * 1024)

    if config.airbrake[:server]&.[](:enabled)
      require 'airbrake'
      require 'airbrake/rack'

      Airbrake.configure do |c|
        c.app_version = Version::SQLUI
        c.environment = config.environment
        c.logger.level = Logger::DEBUG if config.environment != :production?
        config.airbrake[:server].each do |key, value|
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
      redirect config.base_url_path, 301
    end

    resource_path_map = {}
    Dir.glob(File.join(resources_dir, '*')).each do |file|
      hash = Digest::MD5.hexdigest(File.read(file))
      basename = File.basename(file)
      url_path = "#{config.base_url_path}/#{basename}"
      case File.extname(basename)
      when '.svg'
        content_type = 'image/svg+xml; charset=utf-8'
      when '.css'
        content_type = 'text/css; charset=utf-8'
      when '.js'
        content_type = 'text/javascript; charset=utf-8'
      else
        raise "unsupported resource file extension: #{File.extname(basename)}"
      end
      resource_path_map[basename] = "#{url_path}?#{hash}"
      get url_path do
        headers 'Content-Type' => content_type
        headers 'Cache-Control' => 'max-age=31536000'
        send_file file
      end
    end

    get "#{config.base_url_path}/?" do
      headers 'Cache-Control' => 'no-cache'
      erb :databases, locals: { config: config, resource_path_map: resource_path_map }
    end

    config.database_configs.each do |database|
      get "#{config.base_url_path}/#{database.url_path}/?" do
        redirect "#{database.url_path}/query", 301
      end

      post "#{config.base_url_path}/#{database.url_path}/metadata" do
        metadata = database.with_client do |client|
          {
            server: "#{config.name} - #{database.display_name}",
            base_url_path: config.base_url_path,
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

      post "#{config.base_url_path}/#{database.url_path}/query" do
        data = request.body.read
        request.body.rewind # since Airbrake will read the body on error
        params.merge!(JSON.parse(data, symbolize_names: true))
        break client_error('missing sql') unless params[:sql]

        variables = params[:variables] || {}
        queries = find_selected_queries(params[:sql], params[:selection])

        status 200
        headers 'Content-Type' => 'application/json; charset=utf-8'

        stream do |out|
          database.with_client do |client|
            begin
              query_result = execute_query(client, variables, queries)
            rescue Mysql2::Error => e
              stacktrace = e.full_message(highlight: false)
              message = "ERROR #{e.error_number} (#{e.sql_state}): #{e.message.lines.first&.strip || 'unknown error'}"
              out << { error: message, stacktrace: stacktrace }.compact.to_json
              break
            rescue StandardError => e
              stacktrace = e.full_message(highlight: false)
              message = e.message.lines.first&.strip || 'unknown error'
              out << { error: message, stacktrace: stacktrace }.compact.to_json
              break
            end

            if query_result
              json = <<~RES.chomp
                {
                  "columns": #{query_result.fields.to_json},
                  "column_types": #{MysqlTypes.map_to_google_charts_types(query_result.field_types).to_json},
                  "selection": #{params[:selection].to_json},
                  "query": #{params[:sql].to_json},
                  "rows": [
              RES
              out << json
              bytes_written = json.bytesize
              max_rows_written = false
              rows_written = 0
              total_rows = 0
              query_result.each_with_index do |row, i|
                total_rows += 1
                next if max_rows_written

                json = "#{i.zero? ? '' : ','}\n    #{row.map { |v| big_decimal_to_float(v) }.to_json}"
                bytesize = json.bytesize
                if bytes_written + bytesize > Sqlui::MAX_BYTES
                  max_rows_written = true
                  next
                end

                out << json
                bytes_written += bytesize
                rows_written += 1

                if rows_written == Sqlui::MAX_ROWS
                  max_rows_written = true
                  next
                end
              end
              out << <<~RES

                  ],
                  "total_rows": #{total_rows}
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

      get "#{config.base_url_path}/#{database.url_path}/download_csv" do
        break client_error('missing sql') unless params[:sql]

        sql = Base64.decode64(params[:sql]).force_encoding('UTF-8')
        variables = params.map { |k, v| k[0] == '_' ? [k, v] : nil }.compact.to_h
        queries = find_selected_queries(sql, params[:selection])

        content_type 'application/csv; charset=utf-8'
        headers 'Cache-Control' => 'no-cache'
        attachment 'result.csv'
        status 200

        stream do |out|
          database.with_client do |client|
            begin
              query_result = execute_query(client, variables, queries)
            rescue Mysql2::Error => e
              stacktrace = e.full_message(highlight: false)
              message = "ERROR #{e.error_number} (#{e.sql_state}): #{e.message.lines.first&.strip || 'unknown error'}"
              out << { error: message, stacktrace: stacktrace }.compact.to_json
              break
            rescue StandardError => e
              stacktrace = e.full_message(highlight: false)
              message = e.message.lines.first&.strip || 'unknown error'
              out << { error: message, stacktrace: stacktrace }.compact.to_json
              break
            end
            out << CSV::Row.new(query_result.fields, query_result.fields, header_row: true).to_s.strip
            query_result.each do |row|
              out << "\n#{CSV::Row.new(query_result.fields, row.map { |v| big_decimal_to_float(v) }).to_s.strip}"
            end
          end
        end
      end

      get(/#{Regexp.escape("#{config.base_url_path}/#{database.url_path}/")}(query|graph|saved|structure|help)/) do
        status 200
        headers 'Cache-Control' => 'no-cache'
        client_config = config.airbrake[:client] || {}
        erb :sqlui, locals: {
          environment: config.environment.to_s,
          airbrake_enabled: client_config[:enabled] || false,
          airbrake_project_id: client_config[:project_id] || '',
          airbrake_project_key: client_config[:project_key] || '',
          resource_path_map: resource_path_map
        }
      end
    end

    error 400..510 do
      exception = env['sinatra.error']
      stacktrace = exception&.full_message(highlight: false)
      if request.env['HTTP_ACCEPT'] == 'application/json'
        headers 'Content-Type' => 'application/json; charset=utf-8'
        message = "error: #{exception&.message&.lines&.first&.strip || 'unexpected error'}"
        json = { error: message, stacktrace: stacktrace }.compact.to_json
        body json
      else
        message = "#{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
        erb :error, locals: {
          resource_path_map: resource_path_map,
          title: "SQLUI #{message}",
          message: message,
          stacktrace: stacktrace
        }
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

  def find_selected_queries(full_sql, selection)
    if selection
      if selection.include?('-')
        # sort because the selection could be in either direction
        selection = selection.split('-').map { |v| Integer(v) }.sort
      else
        selection = Integer(selection)
        selection = [selection, selection]
      end

      if selection[0] == selection[1]
        [SqlParser.find_statement_at_cursor(full_sql, selection[0])]
      else
        SqlParser.split(full_sql[selection[0], selection[1]])
      end
    else
      SqlParser.split(full_sql)
    end
  end

  def execute_query(client, variables, queries)
    variables.each do |name, value|
      client.query("SET @#{name} = #{value};")
    end
    queries[0..-2].map do |current|
      client.query(current, stream: true)&.free
    end
    client.query(queries[-1], stream: true)
  end

  def big_decimal_to_float(maybe_big_decimal)
    # TODO: This BigDecimal thing needs some thought.
    if maybe_big_decimal.is_a?(BigDecimal)
      big_decimal_string = maybe_big_decimal.to_s('F')
      float = maybe_big_decimal.to_f
      if big_decimal_string == float.to_s
        float
      else
        big_decimal_string
      end
    else
      maybe_big_decimal
    end
  end
end
