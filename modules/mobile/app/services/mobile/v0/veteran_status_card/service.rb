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
        # @see VeteranStatusCard::Service#unknown_eligibility_response
        # @return [Hash] mobile-specific unknown eligibility response
        #
        def unknown_eligibility_response
          Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_ELIGIBILITY_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#currently_serving_response
        # @return [Hash] mobile-specific currently serving response
        #
        def currently_serving_response
          Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#uncaught_error_response
        # @return [Hash] mobile-specific uncaught error response
        #
        def uncaught_error_response
          Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
        end

        ##
        # @see VeteranStatusCard::Service#person_not_found_response
        # @return [Hash] mobile-specific person not found response
        #
        def person_not_found_response
          Mobile::V0::VeteranStatusCard::Constants::PERSON_NOT_FOUND_RESPONSE
        end
      end
    end
  end
end
