# frozen_string_literal: true

require 'erb'
require 'json'
require 'mysql2'
require 'sinatra/base'
require_relative 'sqlui'
require 'yaml'
require_relative 'environment'

if ARGV.include?('-v') || ARGV.include?('--version')
  puts File.read('.version')
  exit
end

raise 'you must specify a configuration file' unless ARGV.size == 1
raise 'configuration file does not exist' unless File.exist?(ARGV[0])

# SQLUI Sinatra server.
class Server < Sinatra::Base
  set :logging, true
  set :bind,    '0.0.0.0'
  set :port,    Environment.server_port
  set :env,     Environment.server_env

  # A MySQL client. This needs to go away.
  class Client
    def initialize(params)
      @params = params
    end

    def query(sql)
      client = Thread.current.thread_variable_get(:client)
      unless client
        client = Mysql2::Client.new(@params)
        Thread.current.thread_variable_set(:client, client)
      end
      client.query(sql)
    end
  end

  config = YAML.safe_load(ERB.new(File.read(ARGV[0])).result)
  saved_path_root = config['saved_path']
  client_map = config['databases'].values.to_h do |database_config|
    client_params = {
      host: database_config['db_host'],
      port: database_config['db_port'] || 3306,
      username: database_config['db_username'],
      password: database_config['db_password'],
      database: database_config['db_database'],
      read_timeout: 10, # seconds
      write_timeout: 0, # seconds
      connect_timeout: 5   # seconds
    }
    client = Client.new(client_params)
    [
      database_config['url_path'],
      ::SQLUI.new(
        client: client,
        table_schema: database_config['db_database'],
        name: database_config['name'],
        saved_path: File.join(saved_path_root, database_config['saved_path'])
      )
    ]
  end

  get '/-/health' do
    status 200
    body 'OK'
  end

  get '/db/?' do
    erb :databases, locals: { databases: config['databases'] }
  end

  get '/db/:database' do
    redirect "/db/#{params[:database]}/app", 301
  end

  get '/db/:database/:route' do
    response = client_map[params[:database]].get(params)
    status response[:status]
    headers 'Content-Type': response[:content_type]
    body response[:body]
  end

  post '/db/:database/:route' do
    post_body = JSON.parse(request.body.read)
    response = client_map[params[:database]].post(params.merge(post_body))
    status response[:status]
    headers 'Content-Type': response[:content_type]
    body response[:body]
  end

  run!
end
