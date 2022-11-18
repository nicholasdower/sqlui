# frozen_string_literal: true

# Loads metadata from a database.
class DatabaseMetadata
  def initialize
    raise "can't instantiate #{self.class}"
  end

  class << self
    def lookup(client, database_config)
      result = load_columns(client, database_config)
      load_stats(result, client, database_config)

      result
    end

    private

    def load_columns(client, database_config)
      result = {}
      database = database_config.client_params[:database]
      where_clause = if database
                       "where table_schema = '#{database}'"
                     else
                       "where table_schema not in('mysql', 'sys', 'information_schema', 'performance_schema')"
                     end
      column_result = client.query(
        <<~SQL
          select
            table_schema,
            table_name,
            column_name,
            data_type,
            character_maximum_length,
            is_nullable,
            column_key,
            column_default,
            extra
          from information_schema.columns
          #{where_clause}
          order by table_schema, table_name, column_name, ordinal_position;
        SQL
      )
      column_result.each do |row|
        row = row.transform_keys(&:downcase).transform_keys(&:to_sym)
        table_schema = row[:table_schema]
        unless result[table_schema]
          result[table_schema] = {
            tables: {}
          }
        end
        table_name = row[:table_name]
        tables = result[table_schema][:tables]
        unless tables[table_name]
          tables[table_name] = {
            indexes: {},
            columns: {}
          }
        end
        columns = result[table_schema][:tables][table_name][:columns]
        column_name = row[:column_name]
        columns[column_name] = {} unless columns[column_name]
        column = columns[column_name]
        column[:name] = column_name
        column[:data_type] = row[:data_type]
        column[:length] = row[:character_maximum_length]
        column[:allow_null] = row[:is_nullable]
        column[:key] = row[:column_key]
        column[:default] = row[:column_default]
        column[:extra] = row[:extra]
      end
      result
    end

    def load_stats(result, client, database_config)
      database = database_config.client_params[:database]

      where_clause = if database
                       "where table_schema = '#{database}'"
                     else
                       "where table_schema not in('mysql', 'sys', 'information_schema', 'performance_schema')"
                     end
      stats_result = client.query(
        <<~SQL
          select
            table_schema,
            table_name,
            index_name,
            seq_in_index,
            non_unique,
            column_name
          from information_schema.statistics
          #{where_clause}
          order by table_schema, table_name, if(index_name = "PRIMARY", 0, index_name), seq_in_index;
      SQL
      )
      stats_result.each do |row|
        row = row.transform_keys(&:downcase).transform_keys(&:to_sym)
        table_schema = row[:table_schema]
        tables = result[table_schema][:tables]
        table_name = row[:table_name]
        indexes = tables[table_name][:indexes]
        index_name = row[:index_name]
        indexes[index_name] = {} unless indexes[index_name]
        index = indexes[index_name]
        column_name = row[:column_name]
        index[column_name] = {}
        column = index[column_name]
        column[:name] = index_name
        column[:seq_in_index] = row[:seq_in_index]
        column[:non_unique] = row[:non_unique]
        column[:column_name] = row[:column_name]
      end
    end
  end
end
