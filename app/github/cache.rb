# frozen_string_literal: true

require_relative '../checks'

module Github
  # A cache for GitHub API GET requests.
  class Cache
    include Checks

    # A cache entry.
    class Entry
      include Checks

      attr_accessor :value, :expires_at

      def initialize(value, max_age_seconds)
        @value = check_non_nil(value: value)
        @expires_at = Time.now + check_positive_integer(max_age_seconds: max_age_seconds)
      end
    end

    def initialize(hash, logger: Logger.new($stdout))
      @mutex = Mutex.new
      @hash = check_is_a(hash: [Hash, hash])
      @logger = check_non_nil(logger: logger)
    end

    def [](key)
      check_non_empty_string(key: key)

      @mutex.synchronize do
        evict
        if (value = @hash[key])
          @logger.info "#{self.class} entry found for #{key}"
          value
        else
          @logger.info "#{self.class} entry not found for #{key}"
          nil
        end
      end
    end

    def []=(key, value)
      check_non_empty_string(key: key)
      check_is_a(value: [Entry, value])

      @mutex.synchronize do
        @logger.info "#{self.class} caching entry for #{key} until #{value.expires_at}"
        @hash[key] = value
      end
    end

    private

    def evict
      now = Time.now
      @hash.delete_if do |key, value|
        if value.expires_at < now
          @logger.info "#{self.class} evicting #{key}"
          true
        end
      end
    end
  end
end
