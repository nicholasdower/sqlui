require 'watir'
require_relative '../spec_helper.rb'

describe 'all integration' do
  let(:browser) do
    browser = Watir::Browser.new
  end

  after(:suite) do
    browser.close
  end

  it 'loads' do
    browser.goto 'http://localhost:8080/db'
    puts browser.title
    #browser.link(text: 'Guides').click
  end
end
