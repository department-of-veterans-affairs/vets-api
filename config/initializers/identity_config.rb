# frozen_string_literal: true

ENV_PREFIX = 'IDENTITY_SETTINGS'
ENV_SEPARATOR = '__'
SETTINGS_FOLDER = Rails.root.join('config', 'identity_settings')

IdentitySettings = Config::Options.new

Config.setting_files(SETTINGS_FOLDER, Settings.vsp_environment).each do |file|
  IdentitySettings.add_source!(file)
end

secrets_source = Config::Sources::EnvSource.new(ENV, prefix: ENV_PREFIX, separator: ENV_SEPARATOR)
IdentitySettings.add_source!(secrets_source)

IdentitySettings.reload!
