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
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > h2')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    names = name_elements.map(&:text)
    expect(names).to eq(expected_file_names)
  end

  it 'links to the query' do
    name_elements = wait.until do
      elements = driver.find_elements(css: '#saved-box > .saved-list-item > h2')
      elements if elements.size == expected_file_names.size && elements[0].displayed?
    end
    name_elements.first.click
    wait_until_no_results(wait)
    #wait_until_results(wait, ['1', 'Jerry', 'A funny guy.'])
  end
end
