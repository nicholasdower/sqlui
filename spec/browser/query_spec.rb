# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'query' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  shared_examples_for 'a simple query result' do
    it 'loads expected results' do
      headerElements = wait.until do
        elements = driver.find_elements(css: '#result-box > table > thead > tr > th.cell')
        elements if elements.size == 3 && elements.all?(&:displayed?)
      end
      headers = headerElements.map(&:text)
      expect(headers).to eq(%w(id name description))
      rowElements = wait.until { driver.find_elements(css: '#result-box > table > tbody > tr') }
      rows = rowElements.map do |rowElement|
        rowElement.find_elements(css: 'td.cell').map(&:text) 
      end
      expect(rows).to eq([['1', 'Nick', 'A dev on the project.'], ['2', 'Laura', 'A supportive person.']])
    end
  end

  context 'when sql specified in query parameter' do
    before do
      driver.get(url('/db/development/app?sql=select+id%2C+name%2C+description+from+names+order+by+id+limit+2%3B'))
    end
    
    it_behaves_like 'a simple query result'
  end

  context 'when sql specified via editor' do
    before do
    driver.get(url('/db/development/app'))
    editor = wait.until do
      element = driver.find_element(class: 'cm-content')
      element if element.displayed?
    end
    editor.send_keys('select id, name, description from names order by id limit 2;')
    editor.send_keys([:control, :enter])
    end
    
    it_behaves_like 'a simple query result'
  end
end
