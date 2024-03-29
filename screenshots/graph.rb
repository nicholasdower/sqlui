# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'graph' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  it 'is screenshotted' do
    driver.get(url('/sqlui/seinfeld/graph?sql=select+id%2C+id+from+characters%3B&selection=29'))
    driver.manage.window.resize_to(1300, 975)
    wait_until_editor(wait)
    driver.find_element(id: 'submit-button-current').click
    driver.save_screenshot('screenshots/graph.png')
  end
end
