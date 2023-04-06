# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'help' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  it 'is screenshotted' do
    driver.get(url('/sqlui/seinfeld/help'))
    driver.manage.window.resize_to(1024, 768)
    wait_until_displayed(wait, id: 'help-box')
    driver.save_screenshot('screenshots/help.png')
  end
end
