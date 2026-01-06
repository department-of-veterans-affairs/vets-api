# frozen_string_literal: true

# lib/flipper_utils.rb
module FlipperUtils
  # catch that annoying set of errors that happens during startup on a couple of configurations
  # What's happening is that Flipper is not fully initialized and enabled and calls like
  # Flipper.enabled?(feature_name) throw an exception which produces an error in the log on startup.
  # These errors also appear anytime you run a migration or a couple of other tasks.
  def self.safe_enabled?(feature_name)
    return false unless defined?(Flipper) && Flipper.respond_to?(:enabled)

    Flipper.enabled?(feature_name)
  end
end
