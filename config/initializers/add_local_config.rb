# frozen_string_literal: true

vsp_environment = ENV.fetch('SETTINGS__VSP_ENVIRONMENT', nil)

if vsp_environment
  source = Rails.root.join("config/settings/#{vsp_environment}.local.yml").to_s
  Settings.prepend_source!(source)
  Settings.reload!
end
