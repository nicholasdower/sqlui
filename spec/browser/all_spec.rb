# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'all integration' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  context 'query' do
    it 'loads' do
      driver.get(url('/db/development/app'))
      editor = wait.until { driver.find_element(class: 'cm-content') }
      editor.send_keys('select id, name, description from names order by id limit 2;')
      editor.send_keys([:control, :enter])
      headers = wait.until { driver.find_elements(css: '#result-box > table > thead > tr > th.cell') }.map(&:text)
      expect(headers).to eq(%w(id name description))
      rowElements = wait.until { driver.find_elements(css: '#result-box > table > tbody > tr') }
      rows = rowElements.map do |rowElement|
        rowElement.find_elements(css: 'td.cell').map(&:text) 
      end
      expect(rows).to eq([['1', 'Nick', 'A dev on the project.'], ['2', 'Laura', 'A supportive person.']])
    end
  end
end
