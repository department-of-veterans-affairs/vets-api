require 'rails_helper'
require 'capybara/rspec'

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new(args: ['--disable-gpu'])
  driver = Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.server_port = "3000"
Capybara.default_max_wait_time = 10
Capybara.javascript_driver = :selenium_chrome_headless

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = true
end

RSpec.configure do |config|
  config.include(Wist)
end
