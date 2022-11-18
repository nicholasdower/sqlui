# frozen_string_literal: true

require_relative 'sqlui_config'
require_relative 'server'

# Main entry point.
class Sqlui
  MAX_ROWS = 1_000

  def initialize(config_file)
    raise 'you must specify a configuration file' unless config_file
    raise 'configuration file does not exist' unless File.exist?(config_file)

    @config = SqluiConfig.new(config_file)
    @resources_dir = File.join(File.expand_path('..', File.dirname(__FILE__)), 'client', 'resources')
  end

  def run
    Server.init_and_run(@config, @resources_dir)
  end

  def self.from_command_line(args)
    if args.include?('-v') || args.include?('--version')
      puts File.read('.version')
      exit
    end

    raise 'you must specify a configuration file' unless args.size == 1
    raise 'configuration file does not exist' unless File.exist?(args[0])

    Sqlui.new(args[0])
  end
end
