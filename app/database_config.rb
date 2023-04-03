# frozen_string_literal: true

require 'json'
require 'mysql2'
require 'set'

require_relative 'args'
require_relative 'saved_config'

# Config for a single database.
class DatabaseConfig
  attr_reader :display_name, :description, :url_path, :joins, :saved_config, :tables, :columns, :client_params

  def initialize(hash)
    @display_name = Args.fetch_non_empty_string(hash, :display_name).strip
    @description = Args.fetch_non_empty_string(hash, :description).strip
    @url_path = Args.fetch_non_empty_string(hash, :url_path).strip
    raise ArgumentError, 'url_path should not start with a /' if @url_path.start_with?('/')
    raise ArgumentError, 'url_path should not end with a /' if @url_path.end_with?('/')

    saved_config_hash = Args.fetch_optional_hash(hash, :saved_config)
    @saved_config = saved_config_hash.nil? ? nil : SavedConfig.new(saved_config_hash)

    # Make joins an array. It is only a map to allow for YAML extension.
    @joins = (Args.fetch_optional_hash(hash, :joins) || {}).values
    @joins.each do |join|
      next if join.is_a?(Hash) &&
              join.keys.size == 2 &&
              join[:label].is_a?(String) && !join[:label].strip.empty? &&
              join[:apply].is_a?(String) && !join[:apply].strip.empty?

      raise ArgumentError, "invalid join #{join.to_json}"
    end

    @tables = Args.fetch_optional_hash(hash, :tables) || {}
    @tables.each do |table, table_config|
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

    @columns = Args.fetch_optional_hash(hash, :columns) || {}
    @columns.each do |column, column_config|
      unless column_config.is_a?(Hash)
        raise ArgumentError, "invalid column config for #{column} (#{column_config}), expected hash"
      end

      links = Args.fetch_optional_hash(column_config, :links) || {}
      links.each_value do |link_config|
        unless link_config.is_a?(Hash)
          raise ArgumentError, "invalid link config for #{column} (#{link_config}), expected hash"
        end

        unless link_config[:short_name].is_a?(String)
          raise ArgumentError,
                "invalid link short_name for #{column} link (#{link_config[:short_name]}), expected string"
        end
        unless link_config[:long_name].is_a?(String)
          raise ArgumentError, "invalid link long_name for #{column} link (#{link_config[:long_name]}), expected string"
        end
        unless link_config[:template].is_a?(String)
          raise ArgumentError, "invalid link template for #{column} link (#{link_config[:template]}), expected string"
        end
      end
      # Make links an array. It is only a map to allow for YAML extension
      column_config[:links] = links.values
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
