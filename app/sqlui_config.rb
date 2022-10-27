# frozen_string_literal: true

require 'yaml'
require_relative 'database_config'
require_relative 'args'

# App config including database configs.
class SqluiConfig
  attr_reader :name, :list_url_path, :database_configs

  def initialize(filename)
    config = YAML.safe_load(ERB.new(File.read(filename)).result)
    deep_symbolize!(config)
    @name = Args.fetch_non_empty_string(config, :name).strip
    @list_url_path = Args.fetch_non_empty_string(config, :list_url_path).strip
    raise ArgumentError, 'list_url_path should start with a /' unless @list_url_path.start_with?('/')
    if @list_url_path.length > 1 && @list_url_path.end_with?('/')
      raise ArgumentError, 'list_url_path should not end with a /'
    end

    databases = Args.fetch_non_empty_hash(config, :databases)
    @database_configs = databases.map do |_, current|
      DatabaseConfig.new(current)
    end
  end

  def database_config_for(url_path:)
    config = @database_configs.find { |database| database.url_path == url_path }
    raise ArgumentError, "no config found for path #{url_path}" unless config

    config
  end

  private

  def deep_symbolize!(object)
    return object unless object.is_a? Hash

    object.transform_keys!(&:to_sym)
    object.each_value { |child| deep_symbolize!(child) }

    object
  end
end
