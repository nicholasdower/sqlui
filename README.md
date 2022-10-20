# SQLUI

![image](https://user-images.githubusercontent.com/9117775/196360285-c034ba6a-e4f2-410b-b157-6f567811cfd6.png)

## Intro

A web app which can be used to query one or more SQL databases.

## Features

- List configured databases.
- Query a database.
- Share queries via URLs including cursor position.
- Run one of multiple queries in a single editor based on cursor position.
- Run a saved query file.
- Creating a line graph based on query results.
- Inspecting the structure of the database (see structure tab).

## Usage

### Setup

1. Create a config file. See `example_config.yml`.
1. Install the Gem or add it to your `Gemfile`:

```shell
gem install 'sqlui'
```

```ruby
gem 'sqlui'
```

### Running

```shell
sqlui config-file
```

## Development

### Setup

1. `cp example_config.yml config.yml`.
1. Add database configuration to `config.yml`.
1. `nvm install node`

### Building

1. `nvm use`
1. `make install`
1. `make build`

### Running

1. `make run`
1. Visit http://localhost:8080/db
