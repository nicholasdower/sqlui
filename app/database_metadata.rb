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
      load_tables(result, client, database_config)

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
          order by table_schema, table_name, ordinal_position;
        SQL
      )
      column_result.to_a.each do |row|
        table_schema = row.shift
        unless result[table_schema]
          result[table_schema] = {
            tables: {}
          }
        end
        table_name = row.shift
        tables = result[table_schema][:tables]
        unless tables[table_name]
          tables[table_name] = {
            indexes: {},
            columns: {}
          }
        end
        columns = result[table_schema][:tables][table_name][:columns]
        column_name = row.shift
        columns[column_name] = {} unless columns[column_name]
        column = columns[column_name]
        column[:name] = column_name
        column[:data_type] = row.shift
        column[:length] = row.shift
        column[:allow_null] = row.shift
        column[:key] = row.shift
        column[:default] = row.shift
        column[:extra] = row.shift
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
            column_name,
            seq_in_index,
            non_unique
          from information_schema.statistics
          #{where_clause}
          order by table_schema, table_name, if(index_name = "PRIMARY", 0, index_name), seq_in_index;
        SQL
      )
      stats_result.each do |row|
        table_schema = row.shift
        tables = result[table_schema][:tables]
        table_name = row.shift
        indexes = tables[table_name][:indexes]
        index_name = row.shift
        indexes[index_name] = {} unless indexes[index_name]
        index = indexes[index_name]
        column_name = row.shift
        index[column_name] = {}
        column = index[column_name]
        column[:name] = index_name
        column[:seq_in_index] = row.shift
        column[:non_unique] = row.shift
        column[:column_name] = column_name
      end
    end

    def load_tables(result, client, _database_config)
      tables_result = client.query(
        <<~SQL
          SELECT
            TABLE_SCHEMA,
            TABLE_NAME,
            CREATE_TIME,
            UPDATE_TIME,
            ENGINE,
            TABLE_ROWS,
            AVG_ROW_LENGTH,
            DATA_LENGTH,
            INDEX_LENGTH,
            TABLE_COLLATION,
            AUTO_INCREMENT
          FROM information_schema.TABLES;
        SQL
      )
      tables_hash = {}
      tables_result.each do |row|
        table_schema = row.shift
        table_name = row.shift
        tables_hash[table_schema] ||= {}
        tables_hash[table_schema][table_name] = {
          created_at: row.shift,
          updated_at: row.shift,
          engine: row.shift,
          rows: add_thousands_separator(row.shift),
          average_row_size: pretty_data_size(row.shift),
          data_size: pretty_data_size(row.shift),
          index_size: pretty_data_size(row.shift),
          encoding: row.shift,
          auto_increment: add_thousands_separator(row.shift)
        }
      end
      result.each do |table_schema, schema_hash|
        schema_hash[:tables].each do |table_name, table|
          table[:info] = tables_hash[table_schema][table_name]
        end
      end
    end

    def pretty_data_size(size)
      if size.nil?
        return nil
      elsif size < 1024
        unit = "byte#{size == 1 ? '' : 's'}"
        converted = size
      elsif size < 1024 * 1024
        unit = 'KiB'
        converted = (size.to_f / 1024).round(2)
      elsif size < 1024 * 1024 * 1024
        unit = 'MiB'
        converted = (size.to_f / (1024 * 1024)).round(2)
      elsif size < 1024 * 1024 * 1024 * 1024
        unit = 'GiB'
        converted = (size.to_f / (1024 * 1024 * 1024)).round(2)
      end

      "#{add_thousands_separator(converted)} #{unit}"
    end

    def add_thousands_separator(value)
      return nil if value.nil?

      integer = value.round(1).floor
      fractional = ((value.round(1) - integer) * 10).floor

      with_commas = integer.to_s.reverse.scan(/.{1,3}/).join(',').reverse
      if fractional.zero?
        with_commas
      else
        "#{with_commas}.#{fractional}"
      end
    end
  end
end
