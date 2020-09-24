# frozen_string_literal: true

unless Rails.env.production?
  begin
    ERB.new(File.read(Settings.betamocks.services_config)).result
  rescue NoMethodError
    raise ArgumentError, 'betamocks services_config error, check that vars from settings.yml are interpolated correctly'
  end
end

Betamocks.configure do |config|
  config.enabled = Settings.betamocks.enabled
  config.cache_dir = Settings.betamocks.cache_dir
  config.services_config = Settings.betamocks.services_config
  config.recording = Settings.betamocks.recording
end
