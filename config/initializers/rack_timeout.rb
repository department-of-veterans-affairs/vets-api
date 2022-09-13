# frozen_string_literal: true

# Adds a global timeout for all requests
if !Rails.env.test? && Settings.rack_timeout
  # @see https://github.com/zombocom/rack-timeout/blob/main/doc/settings.md
  Rails.application.configure do |config|
    config.middleware.insert_before(
      Rack::Runtime, Rack::Timeout,
      # Default of 0 disables rack timeout unless the ENV variable is set
      service_timeout: Settings.rack_timeout.service_timeout || 0,
      wait_timeout: Settings.rack_timeout.wait_timeout || 0,
      wait_overtime: Settings.rack_timeout.wait_overtime || 0
    )
  end
end
