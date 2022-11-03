# SQLUI

![image](https://user-images.githubusercontent.com/9117775/196360285-c034ba6a-e4f2-410b-b157-6f567811cfd6.png)

## Intro

A web app which can be used to query one or more SQL databases.

## Contents

- [Features](#features)
- [Usage](#usage)
- [Development](#development)
  + [Default Setup](#default-setup)
  + [Running The Server & Tests Outside of Docker](#running-the-server--tests-outside-of-docker)

## Features

- Querying.
- Graphing.
- Sharing via URL.
- Saved queries.
- Seeing DB structure.

## Usage

### Create a config file like the following

```yaml
name: some_name      # Server display name to be used in the UI.
list_url_path: /path # Absolute URL path used for the databases list.
databases:
  development:
    name:        some_name   # User-facing name.
    port:        8080        # App port.
    environment: development # App environment.
    description: description # User-facing description.
    url_path:    development # Absolute URL path used to access this database.
    saved_path:  path/to/sql # Relative path to the directory containing saved SQL files.
    client_params:
      database:    name        # Database name.
      username:    root        # Database username.
      password:    root        # Database password.
      port:        3306        # Database port.
      host:        127.0.0.1   # Database host.
```

### Install the Gem or add it to your `Gemfile`

```shell
gem install 'sqlui'
```

or

```ruby
gem 'sqlui'
```

### Run the gem directly or via bundle if using a Gemfile

```shell
sqlui config-file
```

or

```shell
bundle exec sqlui config-file
```

## Development

### Default Setup

By default all building, running and testing is done in Docker containers.

#### Install Docker

See https://docs.docker.com/get-docker/

#### Install & Build

```shell
make install build
```

#### Start the database and server

```shell
make start
```

Visit http://localhost:8080/sqlui

#### Run the tests

```shell
make test
```

### Running The Server & Tests Outside of Docker

It is also possible to run the server tests without Docker. Docker is still used for MySQL.

#### Install rvm (Ruby Version Manager)

See https://rvm.io/rvm/install

#### Install Ruby

```shell
rvm install ruby-3.0.0
```

#### Install nvm (Node Version Manager)

See https://github.com/nvm-sh/nvm#installing-and-updating.

#### Install Node

```shell
nvm install 19.0.0
```

#### Install Chromedriver

See https://chromedriver.chromium.org/getting-started

#### Install & Build

```shell
make install-local build-local
```

#### Start the database (Uses Docker)

```shell
make start-db-detached
```

#### Start the server

```shell
make start-server-local
```

Visit http://localhost:8080/sqlui

#### Run the tests

```shell
make test-local
```
