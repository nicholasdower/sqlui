require 'json'
require 'uri'
require 'set'

class SQLUI
  MAX_ROWS = 1_000

  def initialize(name:, saved_path:, max: MAX_ROWS, &block)
    @name = name
    @saved_path = saved_path
    @queryer = block
    @resources_dir = File.join(File.expand_path('..', File.dirname(__FILE__)), 'resources')
  end

  def get(params)
    case params[:route]
    when 'app'
      { body: html.html_safe, status: 200, content_type: 'text/html' }
    when 'sqlui.js'
      { body: javascript, status: 200, content_type: 'text/javascript' }
    when 'metadata'
      { body: metadata.to_json, status: 200, content_type: 'application/json' }
    when 'query_file'
      { body: query_file(params).to_json, status: 200, content_type: 'application/json' }
    else
      { body: "unknown route: #{params[:route]}", status: 404, content_type: 'text/plain' }
    end
  end

  def post(params)
    case params[:route]
    when 'query'
      { body: query(params).to_json, status: 200, content_type: 'text/html' }
    else
      { body: "unknown route: #{params[:route]}", status: 404, content_type: 'text/plain' }
    end
  end

  private

  def html
    @html ||= File.read(File.join(@resources_dir, 'sqlui.html'))
  end

  def javascript
    @javascript ||= File.read(File.join(@resources_dir, 'sqlui.js'))
  end

  def query(params)
    raise 'missing sql' unless params[:sql]
    raise 'missing cursor' unless params[:cursor]

    sql = find_query_at_cursor(params[:sql], Integer(params[:cursor]))
    raise "can't find query at cursor" unless sql

    execute_query(sql)
  end

  def query_file(params)
    if params['file']
      sql = File.read("#{@saved_path}/#{params['file']}")
      execute_query(sql).tap { |r| r[:file] = params[:file] }
    else
      raise 'missing file param'
    end
  end

  def metadata
    @metadata ||= load_metadata
  end

  def load_metadata
    stats_result = @queryer.call(
      <<~SQL.squish
        select
          table_schema,
          table_name,
          index_name,
          seq_in_index,
          non_unique,
          column_name
        from information_schema.statistics
        where table_schema not in('mysql', 'sys')
        order by table_schema, table_name, if(index_name = "PRIMARY", 0, index_name), seq_in_index;
      SQL
    )
    result = {
      server:  @name,
      schemas: {},
      saved:   Dir.glob("#{@saved_path}/*.sql").sort.map do |path|
        {
          filename:    File.basename(path),
          description: File.readlines(path).take_while { |l| l.start_with?('--') }.map { |l| l.sub(/^-- */, '') }.join
        }
      end
    }
    stats_result.each do |row|
      table_schema = row['table_schema']
      unless result[:schemas][table_schema]
        result[:schemas][table_schema] = {
          tables: {}
        }
      end
      tables = result[:schemas][table_schema][:tables]
      table_name = row['table_name']
      unless tables[table_name]
        tables[table_name] = {
          indexes: {},
          columns: {}
        }
      end
      indexes = tables[table_name][:indexes]
      index_name = row['index_name']
      unless indexes[index_name]
        indexes[index_name] = {}
      end
      index = indexes[index_name]
      column_name = row['column_name']
      index[column_name] = {}
      column = index[column_name]
      column[:name] = index_name
      column[:seq_in_index] = row['seq_in_index']
      column[:non_unique] = row['non_unique']
      column[:column_name] = row['column_name']
    end

    column_result = @queryer.call(
      <<~SQL.squish
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
        where table_schema not in('information_schema' 'mysql', 'performance_schema', 'sys')
        order by table_schema, table_name, column_name, ordinal_position;
    SQL
    )
    column_result.each do |row|
      table_schema = row['table_schema']
      table_name = row['table_name']
      column_name = row['column_name']
      next unless result[:schemas][table_schema]
      next unless result[:schemas][table_schema][:tables][table_name]

      columns = result[:schemas][table_schema][:tables][table_name][:columns]
      unless columns[column_name]
        columns[column_name] = {}
      end
      column = columns[column_name]
      column[:name] = column_name
      column[:data_type] = row['data_type']
      column[:length] = row['character_maximum_length']
      column[:allow_null] = row['is_nullable']
      column[:key] = row['column_key']
      column[:default] = row['column_default']
      column[:extra] = row['extra']
    end

    result
  end

  def execute_query(sql)
    result = @queryer.call(sql)
    rows = result.rows
    column_types = result.columns.map { |_| 'string' }
    unless rows.empty?
      maybe_non_null_column_value_exemplars = result.columns.each_with_index.map do |_, index|
        rows.find do |row|
          !row[index].nil?
        end.try(:[], index)
      end
      column_types = maybe_non_null_column_value_exemplars.map do |value|
        case value
        when String, NilClass
          'string'
        when Integer
          'number'
        when Date, Time
          'date'
        else
          value.class.to_s
        end
      end
    end
    {
      query:        sql,
      columns:      result.columns,
      column_types: column_types,
      total_rows:   rows.size,
      rows:         rows.take(MAX_ROWS)
    }
  end

  def find_query_at_cursor(sql, cursor)
    parts_with_ranges = []
    sql.scan(/[^;]*;[ \n]*/) { |part| parts_with_ranges << [part, 0, part.size] }
    parts_with_ranges.inject(0) do |pos, part_with_range|
      part_with_range[1] += pos
      part_with_range[2] += pos
    end
    part_with_range = parts_with_ranges.find { |part_with_range| cursor >= part_with_range[1] && cursor < part_with_range[2] } || parts_with_ranges[-1]
    part_with_range[0]
  end
end
