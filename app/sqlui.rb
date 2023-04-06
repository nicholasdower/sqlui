# frozen_string_literal: true

require 'webrick'

require_relative 'github/cache'
require_relative 'sqlui_config'
require_relative 'server'
require_relative 'version'

# Main entry point.
class Sqlui
  MAX_ROWS = 100_000
  MAX_BYTES = 10 * 1_024 * 1_024 # 10 MB

  def self.logger
    @logger ||= WEBrick::Log.new
  end

  def initialize(config_file)
    raise 'you must specify a configuration file' unless config_file
    raise 'configuration file does not exist' unless File.exist?(config_file)

    @config = SqluiConfig.new(config_file)
    @resources_dir = File.join(File.expand_path('..', File.dirname(__FILE__)), 'client', 'resources')

    # Connect to each database to verify each can be connected to.
    @config.database_configs.each { |database| database.with_client { |client| client } }
  end

  def run
    Server.init_and_run(@config, @resources_dir, github_cache)
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

  private

  def github_cache
    return Github::Cache.new({}, logger: Sqlui.logger) unless ENV['USE_LOCAL_SAVED_FILES']

    paths = Dir.glob('sql/friends/*.sql')
    blobs = paths.map { |path| { 'path' => path, 'sha' => 'foo' } }
    github_cache_hash = {
      'https://api.github.com/repos/nicholasdower/sqlui/git/trees/master?recursive=true' =>
        Github::Cache::Entry.new(
          {
            'sha' => 'foo',
            'truncated' => false,
            'tree' => blobs
          }, 60 * 60 * 24 * 365
        )
    }
    paths.each do |path|
      github_cache_hash["https://api.github.com/repos/nicholasdower/sqlui/contents/#{path}?ref=foo"] =
        Github::Cache::Entry.new(
          {
            'content' => Base64.encode64(File.read(path))
          }, 60 * 60 * 24 * 365
        )
    end
    Github::Cache.new(github_cache_hash, logger: Sqlui.logger)
  end
end
