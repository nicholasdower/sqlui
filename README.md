# SQLUI

![image](https://user-images.githubusercontent.com/9117775/196360285-c034ba6a-e4f2-410b-b157-6f567811cfd6.png)

## Intro

A web app which can be used to query one or more SQL databases.

## Contents

- [Features](#features)
- [Usage](#usage)
- [Development Setup](#development-setup)

## Features

- Querying.
- Graphing.
- Sharing via URL.
- Saved queries.
- Seeing DB structure.

## Usage

### Create a config file like the following

See [example_config.yaml](https://github.com/nicholasdower/sqlui/blob/master/example_config.yml) for an example.

```yaml
saved_path: path # Path to the directory containing saved SQL files.
databases:
  development:
    name:        Development # Database display name to be used in the UI.
    description: description # Database display name to be used in the UI.
    url_path:    development # Path to use in the URL to access this database.
    saved_path:  development # Path within the root saved path containing saved SQL files.
    db_database: development # Database name.
    db_username: root        # Database username.
    db_password: root        # Database password.
    db_port:     60330       # Database port.
    db_host:     127.0.0.1   # Database host.
```

### Install the Gem or add it to your `Gemfile`

```shell
gem install 'sqlui'
```

```ruby
gem 'sqlui'
```

### Run the gem directly or via bundle if using a Gemfile

<pre>
sqlui <u>config-file</u>
</pre>

<pre>
bundle exec sqlui <u>config-file</u>
</pre>

## Development Setup

### Create a config file like the following

See [example_config.yaml](https://github.com/nicholasdower/sqlui/blob/master/example_config.yml) for an example.

```yaml
saved_path: path # Path to the directory containing saved SQL files.
databases:
  development:
    name:        Development # Database display name to be used in the UI.
    description: description # Database display name to be used in the UI.
    url_path:    development # Path to use in the URL to access this database.
    saved_path:  development # Path within the root saved path containing saved SQL files.
    db_database: development # Database name.
    db_username: root        # Database username.
    db_password: root        # Database password.
    db_port:     60330       # Database port.
    db_host:     127.0.0.1   # Database host.
```

### Install Node Version Manager (nvm)

See https://github.com/nvm-sh/nvm#installing-and-updating.

### Install Node

```shell
nvm install 19
```

### Build & Run

#### Install dependencies

```shell
make install
```

#### Build app

```shell
make build
```

### Start and seed the database

```shell
make start-db seed-db
```

#### Run the tests

```shell
make test
```

#### Run and view the app

```shell
make start
```

Visit http://localhost:8080/db
