# frozen_string_literal: true

require 'active_record'

class ConnectionHolder < ActiveRecord::Base
  self.abstract_class = true

  def self.connection_pool_for(env, config)
    # Is this real life? I couldn't figure out how to just create a connection pool. This is copied almost exactly
    # from the Standby gem.
    klass = Class.new(ConnectionHolder) do
      self.abstract_class = true
    end
    klass_name = env.to_s.downcase.split(/[^a-z]/).map{|e| e.capitalize}.join + 'ConnectionHolder'
    Object.const_set(klass_name, klass)
    klass.establish_connection config
    klass.connection_pool
  end
end
