# frozen_string_literal: true

require 'base64'
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

      raise "GET #{url} returned #{response.code}, expected 200: #{response}" unless response.code == 200

      JSON.parse(response)
    rescue RestClient::RequestFailed => e
      @logger.error("#{self.class} GET #{url} failed: #{e.response.code} #{e.response}")
      raise e
    end

    def post(url, request)
      check_non_empty_string(url: url)
      check_is_a(request: [Hash, request])

      @logger.info "#{self.class} POST #{url}"
      response = RestClient.post(
        url,
        request.to_json,
        {
          'Accept' => 'application/vnd.github+json',
          'Authorization' => "Bearer #{@access_token}",
          'X-GitHub-Api-Version' => '2022-11-28'
        }
      )
      raise "POST #{url} failed: #{response.code} #{response}" unless response.code == 201

      JSON.parse(response)
    rescue RestClient::RequestFailed => e
      @logger.error("#{self.class} POST #{url} failed: #{e.response.code} #{e.response}")
      raise e
    end
  end
end
