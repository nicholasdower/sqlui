# frozen_string_literal: true

require 'base64'

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'saved' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  before do
    driver.get(url('/sqlui/friends/saved'))
  end

  let(:expected_file_names) do
    %w[nicholasdower/sqlui/master/sql/friends/sample_one.sql nicholasdower/sqlui/master/sql/friends/sample_two.sql]
  end

  it 'name links to query' do
    name_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .saved-file-header > .saved-name')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    names = name_elements.map(&:text)
    expect(names).to eq(expected_file_names)
    name_elements.first.click
    wait_until_no_results(wait)
  end

  it 'github links to the file on github.com' do
    github_link_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .saved-file-header > .saved-github-link')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    github_link_elements.first.click
    driver.switch_to.window(driver.window_handles.last)
    expect(driver.current_url).to eq('https://github.com/nicholasdower/sqlui/blob/master/sql/friends/sample_one.sql')
  end
end
