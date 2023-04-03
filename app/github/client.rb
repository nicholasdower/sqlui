# frozen_string_literal: true

require 'json'
require 'logger'
require 'rest-client'

require_relative '../checks'

module Github
  # It's a GitHub client. I know there is an official client library.
  class Client
    include Checks

    def initialize(access_token:, logger: Logger.new($stdout))
      @access_token = check_non_empty_string(access_token: access_token)
      @logger = check_non_nil(logger: logger)
    end

    def get(url)
      check_non_empty_string(url: url)

      @logger.info "#{self.class} GET #{url}"
      response = RestClient.get(
        url,
        {
          'Accept' => 'application/vnd.github+json',
          'Authorization' => "Bearer #{@access_token}",
          'X-GitHub-Api-Version' => '2022-11-28'
        }
      )
      raise "get #{url} failed: #{response}" unless response.code == 200

      JSON.parse(response)
    end
  end
end
