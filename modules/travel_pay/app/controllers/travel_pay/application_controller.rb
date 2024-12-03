# frozen_string_literal: true

module TravelPay
  class ApplicationController < ::ApplicationController
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection
    service_tag 'travel-pay'

    protect_from_forgery with: :exception

    before_action :authenticate
    after_action :scrub_logs

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

    before_action :block_if_flag_disabled

    protected

    def scrub_logs
      logger.filter = lambda do |log|
        if (log.name =~ /TravelPay/) && (log.payload[:action].eql? 'show')
          log.payload[:params]['id'] = 'SCRUBBED_CLAIM_ID'
          log.payload[:path] = log.payload[:path].gsub(%r{(.+claims/)(.+)}, '\1SCRUBBED_CLAIM_ID')

          # Conditional because no referer if directly using the API
          if log.named_tags.key? :referer
            log.named_tags[:referer] = log.named_tags[:referer].gsub(%r{(.+claims/)(.+)(.+)}, '\1SCRUBBED_CLAIM_ID')
          end
        end
        # After the log has been scrubbed, make sure it is logged:
        true
      end
    end

    def before_logger
      logger.info('travel-pay') { Utils::Logger.build(self).before }
    end

    def after_logger
      logger.info('travel-pay') { Utils::Logger.build(self).after }
    end

    def block_if_flag_disabled
      raise_access_denied unless Flipper.enabled?(:travel_pay_power_switch, @current_user)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to travel pay'
    end
  end
end
