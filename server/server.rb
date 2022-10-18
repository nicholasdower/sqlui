require 'json'
require 'sinatra'

get '/app' do
  status 200
  headers "Content-Type": "text/html"
  body File.read('resources/sqlui.html')
end

get '/sqlui.js' do
  status 200
  headers "Content-Type": "text/javascript"
  body File.read('resources/sqlui.js')
end

post '/query' do
  status 200
  headers "Content-Type": "application/json"
  result = {
    query:        params['sql'],
    columns:      ['name'],
    column_types: ['string'],
    total_rows:   1,
    rows:         [['Nick']]
  }
  body result.to_json
end

get '/query_file' do
  status 200
  headers "Content-Type": "application/json"
  result = {
  }
  result = {
    query:        'select * from test;',
    columns:      ['name'],
    column_types: ['string'],
    total_rows:   1,
    rows:         [['Nick']],
    file:         params['file']
  }
  body result.to_json
end

get '/metadata' do
  status 200
  headers "Content-Type": "application/json"
  result = {
    server: 'SQLUI Test Server',
    schemas: {
      schema: {
        tables: {
          table_one: {
            indexes: {
              index: {
                column: {
                  foo: 1
                }
              }
            },
            columns: {
              column: {
                foo: 1
              }
            }
          }
        }
      }
    },
    saved: [
      { filename: 'test_file.sql', description: 'Lists stuff' }
    ]
  }
  body result.to_json
end
