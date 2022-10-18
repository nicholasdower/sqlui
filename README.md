# SQLUI

![image](https://user-images.githubusercontent.com/9117775/196360285-c034ba6a-e4f2-410b-b157-6f567811cfd6.png)

## Intro

A web app which can be used to query a SQL database. Meant to be added to an existing server.

## Features

- Querying.
- Sharing queries via URLs including cursor position.
- Running one of multiple queries in a single editor based on cursor position.
- Running a saved query (see saved tab).
- Creating a line graph based on results.
- Inspecting the structure of the database (see structure tab).

## Usage

### Rails

Add the Gem to your `Gemfile`:

```ruby
gem 'sqlui', '~> 0.1'
```

Add a controller:

```ruby
require 'sqlui'

class SqluiController < ApplicationController
  SQLUI_INSTANCE = ::SQLUI.new(name: "SQLUI (#{Rails.env.titleize})", saved_path: 'db/sql') do |sql|
    ActiveRecord::Base.connection.execute(sql)
  end

  def get
    render SQLUI_INSTANCE.get(params)
  end

  def post
    render SQLUI_INSTANCE.post(params)
  end
end
```

Add the required routes:

```ruby
get  '/sqlui/:route' => 'sqlui#get',  constraints: { route: /.*/ }
post '/sqlui/:route' => 'sqlui#post', constraints: { route: /.*/ }
```

Visit `/sqlui/app`

## Development

### Setup

1. `nvm install node`

### Building

1. `nvm use`
1. `make install`
1. `make build`

### Running

1. `make test-server`
1. Visit http://localhost:4567/app
