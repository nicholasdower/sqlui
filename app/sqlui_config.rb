# frozen_string_literal: true

require_relative 'database_config'

# App config including database configs.
class SqluiConfig
  attr_reader :name, :list_path, :databases

  def initialize(filename)
    config = YAML.safe_load(ERB.new(File.read(filename)).result)
    deep_symbolize!(config)
    @name = config[:name].strip
    @list_path = config[:list_path].strip
    raise 'list_path should start with a /' unless @list_path.start_with?('/')
    raise 'list_path should not end with a /' if @list_path.length > 1 && @list_path.end_with?('/')

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
