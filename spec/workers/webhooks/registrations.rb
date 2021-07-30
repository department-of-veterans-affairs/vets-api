# frozen_string_literal: true

module Registrations
  include Webhooks::Utilities
  TEST_EVENT = 'registrations_test_api'
  MAX_RETRIES = 3
  register_events(TEST_EVENT, api_name: 'registrations_test_api', max_retries: MAX_RETRIES) do
    30.seconds.from_now
  end
end
