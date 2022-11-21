# frozen_string_literal: true

require 'json'
require 'mysql2'
require 'set'

require_relative 'args'

# Config for a single database.
class DatabaseConfig
  attr_reader :display_name, :description, :url_path, :joins, :saved_path, :tables, :client_params

  def initialize(hash)
    @display_name = Args.fetch_non_empty_string(hash, :display_name).strip
    @description = Args.fetch_non_empty_string(hash, :description).strip
    @url_path = Args.fetch_non_empty_string(hash, :url_path).strip
    raise ArgumentError, 'url_path should start with a /' unless @url_path.start_with?('/')
    raise ArgumentError, 'url_path should not end with a /' if @url_path.length > 1 && @url_path.end_with?('/')

    @saved_path = Args.fetch_non_empty_string(hash, :saved_path).strip
    @joins = Args.fetch_optional_array(hash, :joins) || []
    @joins.map do |join|
      next if join.is_a?(Hash) &&
              join.keys.size == 2 &&
              join[:label].is_a?(String) && !join[:label].strip.empty? &&
              join[:apply].is_a?(String) && !join[:apply].strip.empty?

      raise ArgumentError, "invalid join #{join.to_json}"
    end
    @tables = Args.fetch_optional_hash(hash, :tables) || {}
    @tables = @tables.each do |table, table_config|
      unless table_config.is_a?(Hash)
        raise ArgumentError, "invalid table config for #{table} (#{table_config}), expected hash"
      end

      table_alias = table_config[:alias]
      if table_alias && !table_alias.is_a?(String)
        raise ArgumentError, "invalid table alias for #{table} (#{table_alias}), expected string"
      end

      table_boost = table_config[:boost]
      if table_boost && !table_boost.is_a?(Integer)
        raise ArgumentError, "invalid table boost for #{table} (#{table_boost}), expected int"
      end
    end
    aliases = @tables.map { |_table, table_config| table_config[:alias] }.compact
    if aliases.to_set.size < aliases.size
      duplicate_aliases = aliases.reject { |a| aliases.count(a) == 1 }.to_set
      raise ArgumentError, "duplicate table aliases: #{duplicate_aliases.join(', ')}"
    end

    @client_params = Args.fetch_non_empty_hash(hash, :client_params)
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
