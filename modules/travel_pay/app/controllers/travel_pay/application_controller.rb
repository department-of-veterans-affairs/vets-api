# frozen_string_literal: true

module TravelPay
  class ApplicationController < ::ApplicationController
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection
    service_tag 'travel-pay'

    protect_from_forgery with: :exception

    before_action :authenticate

    ##
    # This before_action is feature flag driven and should be retired
    #
    # Flag name: travel_pay_power_switch
    # Intent:    allow env-specific request blocking
    #
    # Retirement conditions:
    # * Feature is in production
    # * Finer-grained feature flags exist as needed
    #
    # Upon retirement:
    # * Remove feature flag from config/features.yml
    # * Remove feature flag from database (requires platform support for prod)
    # * Remove this before_action
    # * Remove block_if_flag_disabled definition
    # * Remove flag_conditions_met? definition
    #
    before_action :block_if_flag_disabled

    protected

    def raise_access_denied
      raise Common::Exceptions::Unauthorized, detail: 'You do not have access to the requested resource'
    end

    def before_logger
      logger.info('travel-pay') { Utils::Logger.build(self).before }
    end

    def after_logger
      logger.info('travel-pay') { Utils::Logger.build(self).after }
    end

    # Blocks requests from being handled if feature flag is disabled
    def block_if_flag_disabled
      unless Flipper.enabled?(:travel_pay_power_switch, @current_user)
        raise Common::Exceptions::ServiceUnavailable, detail: 'This feature has been temporarily disabled'
      end
    end
  end
end
