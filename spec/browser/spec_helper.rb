# frozen_string_literal: true

require 'selenium-webdriver'
require 'webmock/rspec'

require_relative '../../app/server'
require_relative '../../app/sqlui_config'

LOCAL = %w[1 true].include?(ENV.fetch('LOCAL', 'false').strip.downcase)
CONFIG = SqluiConfig.new('development_config.yml')

def wait_until_displayed(wait, *args)
  wait.until do
    element = driver.find_element(*args)
    element if element&.displayed?
  end
end

def wait_until_all_displayed(wait, *args)
  wait.until do
    elements = driver.find_elements(*args)
    elements if elements&.all?(&:displayed?)
  end
end

def wait_until_editor(wait)
  wait_until_displayed(wait, class: 'cm-content')
end

def wait_until_spinner(wait)
  wait_until_displayed(wait, id: 'result-loader')
end

def wait_until_results(wait, *results)
  expected_headers = results[0]
  expected_rows = results[1..]
  wait_until_status(wait, "#{expected_rows.size} row#{expected_rows.size == 1 ? '' : 's'}")
  header_elements = wait.until do
    elements = driver.find_elements(css: '#result-box > table > thead > tr > th:not(:last-child)')
    elements if elements.size == expected_headers.size && elements.all?(&:displayed?)
  end
  headers = header_elements.map(&:text)
  expect(headers).to eq(expected_headers)
  row_elements = wait.until { driver.find_elements(css: '#result-box > table > tbody > tr') }
  rows = row_elements.map do |row_element|
    row_element.find_elements(css: 'td:not(:last-child)').map(&:text)
  end
  expect(rows).to eq(expected_rows)
end

def wait_until_status(wait, status)
  wait.until do
    element = driver.find_element(id: 'status-message')
    element if element.text.match(status)
  end
end

def wait_until_no_results(wait, status_matcher = '')
  wait_until_status(wait, status_matcher)
  wait.until do
    driver.find_element(css: '#result-box > table')
  rescue Selenium::WebDriver::Error::NoSuchElementError
    true
  end
end

def url(path)
  "http://#{ENV.fetch('APP_HOST')}:#{CONFIG.port}#{path}"
end

class TestServer
  @github_cache_hash = {}

  class << self
    attr_reader :github_cache_hash
  end

  def self.clear_github_cache
    @github_cache_hash.clear
  end

  def start
    @thread = Thread.new do
      Server.set :server, 'webrick'
      Server.init_and_run(CONFIG, 'client/resources',
                          Github::Cache.new(TestServer.github_cache_hash, logger: Server.logger))
    end

    (1..20).each do |n|
      break if Server.running?
      raise 'server failed to start' if n == 20

      sleep 0.5
    end
  end

  def stop
    Server.quit!
    @thread&.join
  end
end

test_server = TestServer.new

WebMock.disable_net_connect!(allow_localhost: true, allow: ['sqlui_hub'])

RSpec.configure do |config|
  config.before(:suite) { test_server.start }

  config.after(:suite) { test_server.stop }

  config.after do
    @driver&.quit
    TestServer.clear_github_cache
  end

  def start_session
    @driver = if LOCAL
                Selenium::WebDriver.for(:chrome)
              else
                Selenium::WebDriver.for(:remote, url: 'http://sqlui_hub:4444/wd/hub', capabilities: :chrome)
              end
  end
end
