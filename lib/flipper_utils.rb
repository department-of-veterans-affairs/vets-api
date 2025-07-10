# frozen_string_literal: true

# lib/flipper_utils.rb
# catch that annoying set of errors that happens during startup on a couple of configurations
module FlipperUtils
  MAX_WAIT = 3 # seconds

  def self.safe_enabled?(feature_name)
    start_time = Time.now

    until defined?(Flipper) &&
          Flipper.respond_to?(:enabled) &&
          Flipper.instance_variable_get(:@memoized) # crude check for init
      return false if Time.now - start_time > MAX_WAIT

      sleep 0.1
    end

    Flipper.enabled?(feature_name)
  rescue => e
    Rails.logger.warn("Flipper check failed for #{feature_name}: #{e.class} - #{e.message}")
    false
  end
end
