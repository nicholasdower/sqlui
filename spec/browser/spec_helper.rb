require 'watir'

LOCAL = ['1', 'true'].include?(ENV.fetch('LOCAL', 'false').strip.downcase)
SERVER_HOST = ENV.fetch('SERVER_HOST', LOCAL ? 'localhost' : 'server')
SERVER_PORT = ENV.fetch('SERVER_PORT', 8080)

RSpec.configure do |config|
  config.add_setting :browser

  config.before(:suite) do
    RSpec.configuration.browser = LOCAL ? Watir::Browser.new(:chrome) : Watir::Browser.new(:chrome, { url: "http://hub:4444/wd/hub" })
  end

  config.after :suite do
    RSpec.configuration.browser.close
  end
end