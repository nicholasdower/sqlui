require_relative '../spec_helper'
require_relative 'spec_helper'

describe 'all integration' do
  let(:browser) { RSpec.configuration.browser }

  it 'loads' do
    browser.goto "http://#{SERVER_HOST}:#{SERVER_PORT}/db"
    #browser.title
    #browser.link(text: 'Guides').click
  end
end
