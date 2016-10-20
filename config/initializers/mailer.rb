require 'feature_flipper'

if FeatureFlipper.send_email?
  ActionMailer::Base.delivery_method = :govdelivery_tms
  ActionMailer::Base.govdelivery_tms_settings = {
    auth_token: ENV['GOVDELIVERY_TOKEN'],
    api_root: "https://#{FeatureFlipper.staging_email? ? 'stage-' : ''}tms.govdelivery.com"
  }
end
