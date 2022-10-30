# frozen_string_literal: true

require 'selenium-webdriver'

LOCAL = %w[1 true].include?(ENV.fetch('LOCAL', 'false').strip.downcase)
SERVER_HOST = ENV.fetch('SERVER_HOST', LOCAL ? 'localhost' : 'server')
SERVER_PORT = ENV.fetch('SERVER_PORT', 8080)

def wait_until_editor(wait)
  wait.until do
    element = driver.find_element(class: 'cm-content')
    element if element.displayed?
  end
end

def wait_until_results(wait, *results)
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

def wait_until_no_results(wait)
  wait.until do
    driver.find_elements(css: '#result-box > table > thead > tr > th.cell').empty?
  end
  wait.until do
    driver.find_elements(css: '#result-box > table > tbody > tr').empty?
  end
end

def wait_until_query_error(wait, error_matcher)
  error_element = wait.until do
    element = driver.find_element(css: '#status-box > #result-status')
    element if element&.displayed?
  end
  expect(error_element.text).to match(error_matcher)
end

def url(path)
  "http://#{SERVER_HOST}:#{SERVER_PORT}#{path}"
end

RSpec.configure do |config|
  config.after { @driver&.quit }

  def start_session
    @driver = if LOCAL
                Selenium::WebDriver.for(:chrome)
              else
                Selenium::WebDriver.for(:remote, url: 'http://hub:4444/wd/hub', capabilities: :chrome)
              end
  end
end
