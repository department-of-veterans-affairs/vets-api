# frozen_string_literal: true

require 'rspec/rails'

RSpec.configure do |config|
  config.before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, instance_of(User)).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(false)
  end
end
