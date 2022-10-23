# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'query' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  def wait_until_editor
    wait.until do
      element = driver.find_element(class: 'cm-content')
      element if element.displayed?
    end
  end

  def wait_until_results(*results)
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

  shared_examples_for 'a query result' do |results|
    it 'loads expected results' do
      wait_until_results(results)
    end
  end

  context 'when sql specified in query parameter' do
    before do
      driver.get(url('/db/seinfeld/app?sql=select+id%2C+name%2C+description+from+characters+order+by+id+limit+2%3B'))
    end

    it 'loads expected results' do
      wait_until_results(['1', 'Jerry', 'A funny guy.'], ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end

  context 'when sql specified via editor' do
    before do
      driver.get(url('/db/seinfeld/app'))
      editor = wait_until_editor
      editor.send_keys('select id, name, description from characters order by id limit 2;')
      editor.send_keys(%i[control enter])
    end

    it 'loads expected results' do
      wait_until_results(['1', 'Jerry', 'A funny guy.'], ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end

  context 'when first of two editor queries executed via cursor position' do
    before do
      driver.get(url('/db/seinfeld/app'))
      editor = wait_until_editor
      editor.send_keys(
        <<~SQL
          select id, name, description from characters where id = 1;

          select id, name, description from characters where id = 2;
        SQL
      )
      editor.send_keys(%i[up up up])
      editor.send_keys(%i[control enter])
    end

    it 'loads expected results' do
      wait_until_results(['1', 'Jerry', 'A funny guy.'])
    end
  end

  context 'when second of two editor queries executed via cursor position' do
    before do
      driver.get(url('/db/seinfeld/app'))
      editor = wait_until_editor
      editor.send_keys(
        <<~SQL
          select id, name, description from characters where id = 1;

          select id, name, description from characters where id = 2;
        SQL
      )
      editor.send_keys(%i[control enter])
    end

    it 'loads expected results' do
      wait_until_results(['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end
end
