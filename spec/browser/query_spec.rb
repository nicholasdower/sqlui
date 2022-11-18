# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'query' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  context 'when sql specified in query parameter with run' do
    before do
      driver.get(
        url(
          '/sqlui/seinfeld/query' \
          '?sql=select+id%2C+name%2C+description+from+characters+order+by+id+limit+2%3B&run=true'
        )
      )
    end

    it 'does not load any results' do
      wait_until_no_results(wait)
    end
  end

  context 'when sql specified in query parameter without run' do
    before do
      driver.get(
        url('/sqlui/seinfeld/query?sql=select+id%2C+name%2C+description+from+characters+order+by+id+limit+2%3B')
      )
    end

    it 'does not load any results' do
      wait_until_no_results(wait)
    end
  end

  shared_examples_for 'submitted queries' do
    context 'when sql specified in query parameter' do
      before do
        driver.get(
          url('/sqlui/seinfeld/query?sql=select+id%2C+name%2C+description+from+characters+order+by+id+limit+1%3B')
        )
        execute
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'])
      end
    end

    context 'when single editor query specified' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys('select id, name, description from characters order by id limit 2;')
        execute
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'],
                           ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
      end
    end

    context 'when first of two editor queries executed via cursor position' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys(
          <<~SQL
            select id, name, description from characters where id = 1;

            select id, name, description from characters where id = 2;
          SQL
        )
        editor.send_keys(%i[up up up])
        execute
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'])
      end
    end

    context 'when second of two editor queries executed via cursor position' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys(
          <<~SQL
            select id, name, description from characters where id = 1;

            select id, name, description from characters where id = 2;
          SQL
        )
        execute
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
      end
    end

    context 'when invalid sql executed via editor' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys('foo')
        execute
      end

      it 'displays an error and no results' do
        wait_until_no_results(wait, /^error: You have an error in your SQL syntax;/)
      end
    end

    context 'when multiple statements executed via selection' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys(
          <<~SQL
            set @foo = 2;

            select id, name, description from characters where id = @foo;
          SQL
        )
        editor.send_keys(%i[shift up up up])
        execute
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
      end
    end

    context 'when multiple statements executed' do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys(
          <<~SQL
            set @foo = 2;

            select id, name, description from characters where id = @foo;
          SQL
        )
        execute_all
      end

      it 'loads expected results' do
        wait_until_results(wait, %w[id name description], ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
      end
    end
  end

  context 'when keyboarding' do
    let(:execute) do
      wait.until do
        element = driver.find_element(class: 'cm-content')
        element if element&.displayed?
      end.send_keys(%i[control enter])
    end
    let(:execute_all) do
      wait.until do
        element = driver.find_element(class: 'cm-content')
        element if element&.displayed?
      end.send_keys(%i[shift control enter])
    end

    include_examples 'submitted queries'
  end

  context 'when mousing' do
    let(:execute) do
      wait_until_displayed(wait, id: 'submit-button-current').click
    end
    let(:execute_all) do
      wait_until_displayed(wait, id: 'submit-dropdown-button').click
      wait_until_displayed(wait, id: 'submit-dropdown-button-all').click
    end

    include_examples 'submitted queries'
  end

  %w[tab window].each do |tab_or_window|
    context "when running all in a new #{tab_or_window}" do
      before do
        driver.get(url('/sqlui/seinfeld/query'))
        editor = wait_until_editor(wait)
        editor.send_keys('select id, name, description from characters order by id limit 2;')
        wait_until_displayed(wait, id: 'submit-dropdown-button').click
        element = wait_until_displayed(wait, id: 'submit-dropdown-button-all')
        driver.action.key_down(tab_or_window == 'tab' ? :meta : :shift).click(element).perform
      end

      it "loads results in new window, not in current #{tab_or_window}" do
        driver.switch_to.window(driver.window_handles.last)
        wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'],
                           ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
        driver.close
        driver.switch_to.window(driver.window_handles.first)
        wait_until_no_results(wait)
      end
    end
  end

  context 'when a query takes a while' do
    queue = Queue.new
    before do
      config = CONFIG.database_configs.find { |c| c.display_name == 'Seinfeld' }
      original_with_client = config.method(:with_client)
      allow(config).to receive(:with_client) do |&block|
        queue.pop
        original_with_client.call(&block)
      end
      queue << 'initialize'
      driver.get(url('/sqlui/seinfeld/query'))
      editor = wait_until_editor(wait)
      editor.send_keys('select id, name, description from characters order by id limit 2;')
      driver.find_element(id: 'submit-button-current').click
    end

    it 'displays a spinner then results' do
      wait_until_spinner(wait)
      queue << 'execute_query'
      wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'],
                         ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end

    it 'can be cancelled' do
      wait_until_spinner(wait)
      driver.find_element(id: 'cancel-button').click
      queue << 'execute_query'
      wait_until_no_results(wait, 'query cancelled')
    end
  end

  context 'when query variable specified via URL' do
    before do
      driver.get(url('/sqlui/seinfeld/query?_foo=99'))
      editor = wait_until_editor(wait)
      editor.send_keys('select @foo;')
      driver.find_element(id: 'submit-button-current').click
    end

    it 'loads expected results' do
      wait_until_results(wait, ['@foo'], ['99'])
    end
  end
end
