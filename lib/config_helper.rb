# frozen_string_literal: true

require 'feature_flipper'

module ConfigHelper
  module_function

  def setup_action_mailer(config)
    if FeatureFlipper.send_email?
      config.action_mailer.delivery_method = :govdelivery_tms
      config.action_mailer.govdelivery_tms_settings = {
        auth_token: Settings.reports.token,
        api_root: "https://#{Settings.reports.server}"
      }
    end
  end
end
