# frozen_string_literal: true

module TravelPay
  class ApplicationController < ::ApplicationController
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection
    service_tag 'travel-pay'

    protect_from_forgery with: :exception

    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    protected

    def before_logger
      logger.info('travel-pay') { Utils::Logger.build(self).before }
    end

    def after_logger
      logger.info('travel-pay') { Utils::Logger.build(self).after }
    end

    def authorize
      # Not yet implemented
      #routing_error
    end
  end
end
