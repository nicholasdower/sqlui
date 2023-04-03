# frozen_string_literal: true

require_relative '../checks'
require_relative '../deep'
require_relative 'cache'
require_relative 'client'

module Github
  # Like a Github::Client but with a cache.
  class CachingClient
    include Checks

    def initialize(client, cache)
      @client = check_is_a(client: [Client, client])
      @cache = check_is_a(cache: [Cache, cache])
    end

    def get_with_caching(url, cache_for:)
      check_non_empty_string(url: url)
      check_positive_integer(cache_for: cache_for)

      if (cache_entry = @cache[url])
        return cache_entry.value
      end

      response = @client.get(url)
      @cache[url] = Cache::Entry.new(response, cache_for)
      response.deep_dup
    end

    def get_without_caching(url)
      check_non_empty_string(url: url)
      @client.get(url)
    end
  end
end
