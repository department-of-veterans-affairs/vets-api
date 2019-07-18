# frozen_string_literal: true

require 'rails_helper'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'

require 'support/feature_login'

Capybara.server_port = '3000'
Capybara.default_max_wait_time = 10
Capybara.javascript_driver = :selenium_chrome_headless

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = true
end

Settings.virtual_hosts = ['127.0.0.1', 'localhost']
Settings.web_origin = 'http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000,http://127.0.0.1:3001'

DEFAULT_HOST = ENV['DEFAULT_HOST'] || 'http://localhost:3001'

RSpec.configure do |config|
  config.include(Wist)
  config.include(FeatureLogin)
end
