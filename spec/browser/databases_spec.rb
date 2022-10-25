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
      elements if elements&.size == 1 && elements.all?(&:displayed?)
    end

    description_element = database_elements[0].find_element(css: '.description')
    expect(description_element.text).to eq('A database about nothing.')

    name_element = database_elements[0].find_element(css: '.name')
    expect(name_element.text).to eq('Seinfeld')
  end

  it 'links to the query tab' do
    database_elements = wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 1 && elements.all?(&:displayed?)
    end
    query_element = database_elements[0].find_element(css: '.query-link')
    query_element.click
    wait.until do
      element = driver.find_element(css: '#result-box')
      element if element&.displayed?
    end
    driver.navigate.back
  end

  it 'links to the saved tab' do
    database_elements = wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 1 && elements.all?(&:displayed?)
    end
    saved_element = database_elements[0].find_element(css: '.saved-link')
    saved_element.click
    wait.until do
      element = driver.find_element(css: '#saved-box')
      element if element&.displayed?
    end
    driver.navigate.back
  end

  it 'links to the query tab' do
    database_elements = wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 1 && elements.all?(&:displayed?)
    end
    structure_element = database_elements[0].find_element(css: '.structure-link')
    structure_element.click
    wait.until do
      element = driver.find_element(css: '#structure-box')
      element if element&.displayed?
    end
    driver.navigate.back
  end
end
