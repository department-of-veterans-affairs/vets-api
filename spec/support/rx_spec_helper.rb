# frozen_string_literal: true

require 'rspec/rails'

RSpec.configure do |config|
  config.before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_new_policy, anything).and_return(false)
  end
end
