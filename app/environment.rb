# frozen_string_literal: true

# Parses and provides access to environment variables.
class Environment
  APP_ENV = ENV.fetch('APP_ENV', 'development').to_sym
  APP_PORT = ENV.fetch('APP_PORT', 8080)

  def self.server_env
    APP_ENV
  end

  def self.development?
    APP_ENV == :development
  end

  def self.production?
    APP_ENV == :production
  end

  def self.server_port
    APP_PORT
  end
end
