# frozen_string_literal: true

require 'spec_helper'
require 'rspec/rails'

RSpec.configure do |config|
  config.before(:suite) do
    # Ensure that Flipper is disabled globally for all tests
    Flipper.disable(:mhv_secure_messaging_cerner_pilot)
  end

  config.after(:each) do
    # Ensure that Flipper is disabled globally for all tests
    Flipper.disable(:mhv_secure_messaging_cerner_pilot)
  end

end