require 'feature_flipper'

if FeatureFlipper.email_token_present?
  require 'action_mailer/railtie'

  class VetsAPI::Application < Rails::Application
    config.action_mailer.delivery_method = :govdelivery_tms
    config.action_mailer.govdelivery_tms_settings = {
      auth_token: ENV['GOVDELIVERY_TOKEN'],
      api_root: "https://#{FeatureFlipper.staging_email? ? 'stage-' : ''}tms.govdelivery.com"
    }
  end
end
