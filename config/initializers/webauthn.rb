# frozen_string_literal: true

WebAuthn.configure do |config|
  config.rp_name         = "#{Settings.vsp_environment} Va.gov Sign In"
  config.allowed_origins = Settings.web_origin.split(',')
  config.rp_id           = 'localhost'
end
