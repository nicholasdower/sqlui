# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'structure' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  it 'is screenshotted' do
    driver.get(url('/sqlui/seinfeld/structure'))
    driver.manage.window.resize_to(1300, 975)
    wait_until_displayed(wait, id: 'columns')
    driver.save_screenshot('screenshots/structure.png')
  end
end
