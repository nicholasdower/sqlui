# frozen_string_literal: true

# Config for a single database.
class DatabaseConfig
  attr_reader :display_name, :description, :url_path, :saved_path, :client_params, :database

  def initialize(hash)
    @display_name = hash[:display_name].strip
    @description = hash[:description].strip
    @url_path = hash[:url_path].strip
    raise 'base_path should start with a /' unless @url_path.start_with?('/')
    raise 'base_path should not end with a /' if @url_path.length > 1 && @url_path.end_with?('/')

    @saved_path = hash[:saved_path].strip
    @client_params = hash[:client_params]
    @database = @client_params[:database].strip
  end

  def client
    client = Thread.current.thread_variable_get(:client)
    unless client
      client = Mysql2::Client.new(@client_params)
      Thread.current.thread_variable_set(:client, client)
    end
    client
  end
end
