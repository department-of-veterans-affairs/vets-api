# frozen_string_literal: true

Betamocks.configure do |config|
  config.enabled = Settings.betamocks.enabled
  config.cache_dir = Settings.betamocks.cache_dir
  config.services_config = Settings.betamocks.services_config
  config.recording = Settings.betamocks.recording
end
