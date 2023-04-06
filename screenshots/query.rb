# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'query' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  it 'is screenshotted' do
    driver.get(url('/sqlui/seinfeld/query'))
    driver.manage.window.resize_to(1200, 900)
    wait_until_editor(wait)
    driver.save_screenshot('screenshots/query.png')
  end
end
