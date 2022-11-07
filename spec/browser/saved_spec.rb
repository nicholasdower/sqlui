# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'saved' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  before do
    driver.get(url('/sqlui/seinfeld/saved'))
  end

  let(:expected_file_names) { %w[sample_one.sql sample_two.sql] }

  it 'displays the list of saved queries' do
    name_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .name-and-links > h2')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    names = name_elements.map(&:text)
    expect(names).to eq(expected_file_names)
  end

  it 'view links to the query' do
    view_link_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .name-and-links > .view-link')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    view_link_elements.first.click
    wait_until_no_results(wait)
  end

  it 'run links to the query and results' do
    run_link_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > .name-and-links > .run-link')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    run_link_elements.first.click
    wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A funny guy.'])
  end
end
