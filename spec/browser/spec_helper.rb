# frozen_string_literal: true

require 'selenium-webdriver'

LOCAL = %w[1 true].include?(ENV.fetch('LOCAL', 'false').strip.downcase)
SERVER_HOST = ENV.fetch('SERVER_HOST', LOCAL ? 'localhost' : 'server')
SERVER_PORT = ENV.fetch('SERVER_PORT', 8080)

def url(path)
  "http://#{SERVER_HOST}:#{SERVER_PORT}#{path}"
end

RSpec.configure do |config|
  config.after { @driver&.quit }

  def start_session
    if LOCAL
      @driver = Selenium::WebDriver.for(:chrome)
    else
      capabilities = Selenium::WebDriver::Remote::Capabilities.chrome
      http_client = Selenium::WebDriver::Remote::Http::Default.new
      @driver = Selenium::WebDriver.for(
        :remote,
        url: 'http://hub:4444/wd/hub',
        capabilities: capabilities,
        http_client: http_client)
    end
  end
end
