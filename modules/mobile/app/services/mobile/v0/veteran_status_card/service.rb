# frozen_string_literal: true

require 'veteran_status_card/service'
require 'mobile/v0/veteran_status_card/constants'

module Mobile
  module V0
    module VeteranStatusCard
      ##
      # Mobile-specific service for generating Veteran Status Card data
      # Inherits from VeteranStatusCard::Service and overrides response methods
      # to use mobile-specific constants and messaging
      #
      class Service < ::VeteranStatusCard::Service
        protected

        ##
        # @see VeteranStatusCard::Service#statsd_key_prefix
        # @return [String] mobile-specific StatsD key prefix
        #
        def statsd_key_prefix
          'veteran_status_card.mobile'
        end

        ##
        # @see VeteranStatusCard::Service#service_name
        # @return [String] mobile-specific service name for logging
        #
        def service_name
          '[Mobile::V0::VeteranStatusCard::Service]'
        end

        ##
        # @see VeteranStatusCard::Service#something_went_wrong_response
        # @return [Hash] mobile-specific something went wrong response
        #
        def something_went_wrong_response
          Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#dishonorable_response
        # @return [Hash] mobile-specific dishonorable discharge response
        #
        def dishonorable_response
          Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#ineligible_service_response
        # @return [Hash] mobile-specific ineligible service response
        #
        def ineligible_service_response
          Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#unknown_service_response
        # @return [Hash] mobile-specific unknown service response
        #
        def unknown_service_response
          Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#edipi_no_pnl_response
        # @return [Hash] mobile-specific EDIPI no PNL response
        #
        def edipi_no_pnl_response
          Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#currently_serving_response
        # @return [Hash] mobile-specific currently serving response
        #
        def currently_serving_response
          Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#error_response
        # @return [Hash] mobile-specific error response
        #
        def error_response
          Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE
        end
      end
    end
  end
end
