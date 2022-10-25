# frozen_string_literal: true

require 'yaml'
require_relative 'database_config'

# App config including database configs.
class SqluiConfig
  attr_reader :name, :list_url_path, :databases

  def initialize(filename)
    config = YAML.safe_load(ERB.new(File.read(filename)).result)
    deep_symbolize!(config)
    @name = config[:name].strip
    @list_url_path = config[:list_url_path].strip
    raise ArgumentError, 'list_url_path should start with a /' unless @list_url_path.start_with?('/')
    if @list_url_path.length > 1 && @list_url_path.end_with?('/')
      raise ArgumentError, 'list_url_path should not end with a /'
    end

    @databases = config[:databases].map do |_, current|
      DatabaseConfig.new(current)
    end
  end

  def database_config_for(url_path:)
    @databases.find { |database| database.url_path == url_path } || raise("no config found for path #{url_path}")
  end

  def deep_symbolize!(object)
    return unless object.is_a? Hash

    object.transform_keys!(&:to_sym)
    object.each_value { |child| deep_symbolize!(child) }
  end
end
