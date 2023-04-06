# frozen_string_literal: true

require_relative '../spec/spec_helper'
require_relative '../spec/browser/spec_helper'

describe 'databases' do
  let(:driver) { start_session }
  let(:wait) { Selenium::WebDriver::Wait.new(timeout: 5) }

  it 'is screenshotted' do
    driver.get(url('/sqlui'))
    driver.manage.window.resize_to(1200, 900)
    wait.until do
      elements = driver.find_elements(css: '.database')
      elements if elements&.size == 3 && elements.all?(&:displayed?)
    end
    driver.save_screenshot('screenshots/databases.png')
  end
end
