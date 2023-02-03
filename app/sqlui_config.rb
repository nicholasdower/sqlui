# frozen_string_literal: true

require 'yaml'
require 'erb'
require_relative 'args'
require_relative 'database_config'
require_relative 'deep'

# App config including database configs.
class SqluiConfig
  attr_reader :name, :port, :environment, :base_url_path, :database_configs, :airbrake

  def initialize(filename, overrides = {})
    config = YAML.safe_load(ERB.new(File.read(filename)).result, aliases: true).deep_merge!(overrides)
    config.deep_symbolize_keys!
    # Dup since if anchors are used some keys might refer to the same object. If we end up modifying an object,
    # we don't want it to be modified in multiple places.
    config = config.deep_dup
    @name = Args.fetch_non_empty_string(config, :name).strip
    @port = Args.fetch_non_empty_int(config, :port)
    @environment = Args.fetch_non_empty_string(config, :environment).strip
    @base_url_path = Args.fetch_non_empty_string(config, :base_url_path).strip
    raise ArgumentError, 'base_url_path should start with a /' unless @base_url_path.start_with?('/')
    if @base_url_path.length > 1 && @base_url_path.end_with?('/')
      raise ArgumentError, 'base_url_path should not end with a /'
    end

    databases = Args.fetch_non_empty_hash(config, :databases)
    @database_configs = databases.map do |_, current|
      DatabaseConfig.new(current)
    end
    @airbrake = Args.fetch_optional_hash(config, :airbrake) || { enabled: false }
  end

  def database_config_for(url_path:)
    config = @database_configs.find { |database| database.url_path == url_path }
    raise ArgumentError, "no config found for path #{url_path}" unless config

    config
  end
end
