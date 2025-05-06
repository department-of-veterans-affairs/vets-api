# frozen_string_literal: true

require 'feature_flipper'

module ConfigHelper
  module_function

  def setup_action_mailer(config)
    config.action_mailer.preview_paths = [Rails.root.join('spec', 'mailers', 'previews')]
    config.action_mailer.show_previews = Rails.env.development? || FeatureFlipper.staging_email?

    if FeatureFlipper.send_email?
      config.action_mailer.delivery_method = :govdelivery_tms
      config.action_mailer.govdelivery_tms_settings = {
        auth_token: Settings.govdelivery.token,
        api_root: "https://#{Settings.govdelivery.server}"
      }
    end
  end
end
