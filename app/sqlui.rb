# frozen_string_literal: true

require_relative 'sqlui_config'
require_relative 'server'
require_relative 'version'

# Main entry point.
class Sqlui
  MAX_ROWS = 10_000
  MAX_BYTES = 10 * 1_024 * 1_024

  def initialize(config_file)
    raise 'you must specify a configuration file' unless config_file
    raise 'configuration file does not exist' unless File.exist?(config_file)

    @config = SqluiConfig.new(config_file)
    @resources_dir = File.join(File.expand_path('..', File.dirname(__FILE__)), 'client', 'resources')

    # Connect to each database to verify each can be connected to.
    @config.database_configs.each { |database| database.with_client { |client| client } }
  end

  def run
    Server.init_and_run(@config, @resources_dir)
  end

  def self.from_command_line(args)
    if args.include?('-v') || args.include?('--version')
      puts Version::SQLUI
      exit
    end

    raise 'you must specify a configuration file' unless args.size == 1
    raise 'configuration file does not exist' unless File.exist?(args[0])

    Sqlui.new(args[0])
  end
end
