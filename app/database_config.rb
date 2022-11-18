# frozen_string_literal: true

require 'json'
require 'mysql2'
require 'active_record'
require 'set'

require_relative 'args'
require_relative 'connection_holder'

# Config for a single database.
class DatabaseConfig
  attr_reader :env, :display_name, :description, :url_path, :joins, :saved_path, :table_aliases, :client_params

  def initialize(env, hash)
    @env = env
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
    @table_aliases = Args.fetch_optional_hash(hash, :table_aliases) || {}
    @table_aliases = @table_aliases.each do |table, a|
      raise ArgumentError, "invalid alias for table #{table} (#{a}), expected string" unless a.is_a?(String)
    end
    duplicate_aliases = @table_aliases.reject { |(_, v)| @table_aliases.values.count(v) == 1 }.to_h.values.to_set
    if @table_aliases.values.to_set.size < @table_aliases.values.size
      raise ArgumentError, "duplicate table aliases: #{duplicate_aliases.join(', ')}"
    end

    @client_params = Args.fetch_non_empty_hash(hash, :client_params)
    @connection_pool = ConnectionHolder.connection_pool_for(env, @client_params)
  end

  def with_connection(&block)
    @connection_pool.with_connection(&block)
  end
end
