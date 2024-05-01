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

    before_action :feature_enabled

    protected

    def before_logger
      logger.info('travel-pay') { Utils::Logger.build(self).before }
    end

    def after_logger
      logger.info('travel-pay') { Utils::Logger.build(self).after }
    end

    def feature_enabled
      routing_error unless Flipper.enabled?(:travel_pay_power_switch, @current_user)
    end
  end
end
