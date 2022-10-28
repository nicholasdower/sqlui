# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'query' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  shared_examples_for 'a query result' do |results|
    it 'loads expected results' do
      wait_until_results(wait, results)
    end
  end

  context 'when sql specified in query parameter' do
    before do
      driver.get(url('/sqlui/seinfeld/app?sql=select+id%2C+name%2C+description+from+characters+order+by+id+limit+2%3B'))
    end

    it 'loads expected results' do
      wait_until_results(wait, ['1', 'Jerry', 'A funny guy.'],
                         ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end

  context 'when sql specified via editor' do
    before do
      driver.get(url('/sqlui/seinfeld/app'))
      editor = wait_until_editor(wait)
      editor.send_keys('select id, name, description from characters order by id limit 2;')
      editor.send_keys(%i[control enter])
    end

    it 'loads expected results' do
      wait_until_results(wait, ['1', 'Jerry', 'A funny guy.'],
                         ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end

  context 'when first of two editor queries executed via cursor position' do
    before do
      driver.get(url('/sqlui/seinfeld/app'))
      editor = wait_until_editor(wait)
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
      wait_until_results(wait, ['1', 'Jerry', 'A funny guy.'])
    end
  end

  context 'when second of two editor queries executed via cursor position' do
    before do
      driver.get(url('/sqlui/seinfeld/app'))
      editor = wait_until_editor(wait)
      editor.send_keys(
        <<~SQL
          select id, name, description from characters where id = 1;

          select id, name, description from characters where id = 2;
        SQL
      )
      editor.send_keys(%i[control enter])
    end

    it 'loads expected results' do
      wait_until_results(wait, ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end
end
