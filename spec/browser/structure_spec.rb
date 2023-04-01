# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'structure' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  before do
    driver.get(url('/sqlui/seinfeld/structure'))
  end

  it 'hides the list of schemas' do
    expected_table_names = %w[characters random_data]
    wait.until do
      elements = driver.find_elements(css: '#tables > option')
      elements if elements.size == expected_table_names.size && elements[0].displayed?
    end
    schema_element = wait.until { driver.find_element(css: '#schemas') }
    expect(schema_element.displayed?).to eq(false)
  end

  it 'displays the list of tables' do
    expected_table_names = %w[characters random_data]
    table_elements = wait.until do
      elements = driver.find_elements(css: '#tables > option')
      elements if elements.size == expected_table_names.size && elements[0].displayed?
    end
    table_names = table_elements.map(&:text)
    expect(table_names).to eq(expected_table_names)
  end

  it 'selects the first table by default' do
    expected_table_names = %w[characters random_data]
    wait.until do
      elements = driver.find_elements(css: '#tables > option')
      elements if elements.size == expected_table_names.size && elements[0].displayed?
    end

    expected_headers = %w[name data_type length allow_null key default extra]
    wait.until do
      elements = driver.find_elements(
        css: '#columns > table > thead > tr > th:not(:last-child)'
      )
      elements if elements.size == expected_headers.size && elements.all?(&:displayed?)
    end
  end

  it 'displays columns for the selected table' do
    expected_table_names = %w[characters random_data]
    table_elements = wait.until do
      elements = driver.find_elements(css: '#tables > option')
      elements if elements.size == expected_table_names.size && elements[0].displayed?
    end
    table_elements[1].click

    expected_headers = %w[name data_type length allow_null key default extra]
    header_elements = wait.until do
      elements = driver.find_elements(
        css: '#columns > table > thead > tr > th:not(:last-child)'
      )
      elements if elements.size == expected_headers.size && elements.all?(&:displayed?)
    end
    headers = header_elements.map(&:text)
    expect(headers).to eq(expected_headers)

    expected_column_names = %w[id data]
    column_name_elements = wait.until do
      elements = driver.find_elements(
        css: '#columns > table > tbody > tr > td:first-child'
      )
      elements if elements.size == expected_column_names.size && elements.all?(&:displayed?)
    end
    column_names = column_name_elements.map(&:text)
    expect(column_names).to eq(expected_column_names)
  end

  it 'displays headers for the selected table' do
    expected_table_names = %w[characters random_data]
    table_elements = wait.until do
      elements = driver.find_elements(css: '#tables > option')
      elements if elements.size == expected_table_names.size && elements[0].displayed?
    end
    table_elements[0].click
    expected_headers = %w[name seq_in_index non_unique column_name]
    header_elements = wait.until do
      elements = driver.find_elements(
        css: '#indexes > table > thead > tr > th:not(:last-child)'
      )
      elements if elements.size == expected_headers.size && elements.all?(&:displayed?)
    end
    headers = header_elements.map(&:text)
    expect(headers).to eq(expected_headers)

    expected_index_names = %w[PRIMARY]
    index_name_elements = wait.until do
      elements = driver.find_elements(
        css: '#indexes > table > tbody > tr > td:first-child'
      )
      elements if elements.size == expected_index_names.size && elements.all?(&:displayed?)
    end
    index_names = index_name_elements.map(&:text)
    expect(index_names).to eq(expected_index_names)
  end
end
