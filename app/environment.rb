# frozen_string_literal: true

# Parses and provides access to environment variables.
class Environment
  SERVER_ENV = ENV.fetch('SERVER_ENV', 'development').to_sym
  SERVER_PORT = ENV.fetch('SERVER_PORT', 8080)

  def self.server_env
    SERVER_ENV
  end

  def self.development?
    SERVER_ENV == :development
  end

  def self.production?
    SERVER_ENV == :production
  end

  def self.server_port
    SERVER_PORT
  end
end
