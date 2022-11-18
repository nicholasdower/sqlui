# frozen_string_literal: true

require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'navigation' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  context 'when navigating back to query' do
    before do
      queue = %w[initialize execute]
      config = CONFIG.database_configs[0]
      original_with_client = config.method(:with_client)
      allow(config).to receive(:with_client) do |&block|
        raise if queue.empty?

        queue.shift
        original_with_client.call(&block)
      end

      driver.get(url('/sqlui/seinfeld/query'))
      editor = wait_until_editor(wait)
      editor.send_keys('select id, name, description from characters order by id limit 2;')
      wait_until_displayed(wait, id: 'submit-button-current').click
      wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'],
                         ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
      driver.find_element(id: 'saved-tab-button').click
      wait_until_saved_status(wait, '2 files')
      driver.navigate.back
    end

    it 'loads expected results' do
      wait_until_results(wait, %w[id name description], ['1', 'Jerry', 'A joke maker.'],
                         ['2', 'George', 'A short, stocky, slow-witted, bald man.'])
    end
  end
end
