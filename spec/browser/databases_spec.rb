# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'databases' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  before do
    driver.get(url('/sqlui'))
  end

  it 'loads expected databases' do
    database_elements = wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 3 && elements.all?(&:displayed?)
    end

    descriptions = database_elements.map { |element| element.find_element(css: '.description').text }
    expect(descriptions).to(
      eq(
        [
          'Some databases about nothing.',
          'A database about nothing.',
          'A database about even less.'
        ]
      )
    )
    names = database_elements.map { |element| element.find_element(css: '.name').text }
    expect(names).to eq(%w[Shows Seinfeld Friends])
  end

  it 'links to the query tab' do
    database_elements = wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 3 && elements.all?(&:displayed?)
    end
    database_elements[0].click
    wait.until do
      element = driver.find_element(css: '#result-box')
      element if element&.displayed?
    end
  end
end
