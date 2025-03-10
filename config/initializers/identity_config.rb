# frozen_string_literal: true

identity_settings_files = Config.setting_files(Rails.root.join('config', 'identity_settings'), Settings.vsp_environment)

IdentitySettings = Config.load_files(identity_settings_files)
