# frozen_string_literal: true

unless Settings.vsp_environment == 'production'
  begin
    ERB.new(File.read(Settings.betamocks.services_config)).result
  rescue NoMethodError, ArgumentError
    raise ArgumentError,
          "Betamocks services_config error. Values in settings.yml aren't being interpolated correctly " \
          "for a betamocks configuration in #{Settings.betamocks.services_config}"
  end
end

Betamocks.configure do |config|
  config.enabled = Settings.betamocks.enabled
  config.cache_dir = Settings.betamocks.cache_dir
  config.services_config = Settings.betamocks.services_config
  config.recording = Settings.betamocks.recording
end
