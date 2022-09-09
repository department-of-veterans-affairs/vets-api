# frozen_string_literal: true

# Adds a global timeout for all requests
unless Rails.env.test?
  # @see https://github.com/zombocom/rack-timeout/blob/main/doc/settings.md
  Rails.application.configure do |config|
    # Default of 0 disables rack timeout unless the ENV variable is set
    config.middleware.insert_before(
      Rack::Runtime, Rack::Timeout,
      service_timeout: ENV.fetch('RACK_TIMEOUT_SERVICE_TIMEOUT', 0).to_i,
      wait_timeout: ENV.fetch('RACK_TIMEOUT_WAIT_TIMEOUT', 0).to_i,
      wait_overtime: ENV.fetch('RACK_TIMEOUT_WAIT_OVERTIME', 0).to_i
    )
  end
end
