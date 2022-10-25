# frozen_string_literal: true

require 'mysql2'

# Config for a single database.
class DatabaseConfig
  attr_reader :display_name, :description, :url_path, :saved_path, :client_params, :database

  def initialize(hash)
    @display_name = hash[:display_name].strip
    @description = hash[:description].strip
    @url_path = hash[:url_path].strip
    raise ArgumentError, 'url_path should start with a /' unless @url_path.start_with?('/')
    raise ArgumentError, 'url_path should not end with a /' if @url_path.length > 1 && @url_path.end_with?('/')

    @saved_path = hash[:saved_path].strip
    @client_params = hash[:client_params]
    @database = @client_params[:database].strip
  end

  def with_client(&block)
    client = Mysql2::Client.new(@client_params)
    result = block.call(client)
    client.close
    client = nil
    result
  ensure
    client&.close
  end
end
