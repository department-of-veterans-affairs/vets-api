# frozen_string_literal: true

module CheckIn
  class ApplicationController < ::ApplicationController
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection

    protect_from_forgery with: :exception

    before_action :authorize
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    protected

    def before_logger
      logger.info('HCE-Check-In') { Utils::Logger.build(self).before }
    end

    def after_logger
      logger.info('HCE-Check-In') { Utils::Logger.build(self).after }
    end

    def additional_logging?
      Flipper.enabled?('check_in_experience_logging_enabled')
    end

    def authorize
      routing_error unless Flipper.enabled?('check_in_experience_enabled', params[:cookie_id])
    end
  end
end
