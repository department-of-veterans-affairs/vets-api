# frozen_string_literal: true

require 'rspec/rails'

RSpec.configure do |config|
  config.before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)
  end
end
