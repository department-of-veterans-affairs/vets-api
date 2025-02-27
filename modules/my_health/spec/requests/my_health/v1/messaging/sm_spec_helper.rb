# frozen_string_literal: true

require 'spec_helper'
require 'rspec/rails'

RSpec.configure do |config|
  config.before(:suite) do
    # Ensure that Flipper is disabled globally for all tests
    # Flipper.disable(:mhv_secure_messaging_cerner_pilot)
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, instance_of(User)).and_return(false)
  end

  config.after do
    # Ensure that Flipper is disabled globally for all tests
    # Flipper.disable(:mhv_secure_messaging_cerner_pilot)
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, instance_of(User)).and_return(false)
  end
end
