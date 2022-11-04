# frozen_string_literal: true

require 'selenium-webdriver'
require_relative '../../app/server'
require_relative '../../app/sqlui_config'

LOCAL = %w[1 true].include?(ENV.fetch('LOCAL', 'false').strip.downcase)
APP_PORT = 9090
APP_HOST = LOCAL ? 'localhost' : 'test'
CONFIG = SqluiConfig.new('development_config.yml', { port: APP_PORT, environment: 'test' })

def wait_until_editor(wait)
  wait.until do
    element = driver.find_element(class: 'cm-content')
    element if element&.displayed?
  end
end

def wait_until_spinner(wait)
  wait.until do
    element = driver.find_element(id: 'result-loader')
    element if element&.displayed?
  end
end

def wait_until_results(wait, *results)
  wait_until_result_status(wait, "#{results.size} row#{results.size == 1 ? '' : 's'}")
  header_elements = wait.until do
    elements = driver.find_elements(css: '#result-box > table > thead > tr > th.cell')
    elements if elements.size == results[0].size && elements.all?(&:displayed?)
  end
  headers = header_elements.map(&:text)
  expect(headers).to eq(%w[id name description])
  row_elements = wait.until { driver.find_elements(css: '#result-box > table > tbody > tr') }
  rows = row_elements.map do |row_element|
    row_element.find_elements(css: 'td.cell').map(&:text)
  end
  expect(rows).to eq(results)
end

def wait_until_result_status(wait, status)
  wait.until do
    element = driver.find_element(css: '#result-status')
    element if element&.attribute('style') == 'display: flex;' && element.text.match(status)
  end
end

def wait_until_no_results(wait, status_matcher = '')
  wait_until_result_status(wait, status_matcher)
  wait.until do
    driver.find_element(css: '#result-box > table')
  rescue Selenium::WebDriver::Error::NoSuchElementError
    true
  end
end

def url(path)
  "http://#{APP_HOST}:#{APP_PORT}#{path}"
end

class TestServer
  def start
    @thread = Thread.new do
      Server.set :server, 'webrick'
      Server.init_and_run(CONFIG, 'client/resources')
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

RSpec.configure do |config|
  config.before(:suite) { test_server.start }

  config.after(:suite) { test_server.stop }

  config.after { @driver&.quit }

  def start_session
    @driver = if LOCAL
                Selenium::WebDriver.for(:chrome)
              else
                Selenium::WebDriver.for(:remote, url: 'http://hub:4444/wd/hub', capabilities: :chrome)
              end
  end
end
