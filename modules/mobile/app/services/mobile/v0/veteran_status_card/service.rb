# frozen_string_literal: true

require 'veteran_status_card/service'
require 'mobile/v0/veteran_status_card/constants'

module Mobile
  module V0
    module VeteranStatusCard
      class Service < ::VeteranStatusCard::Service
        protected

        def something_went_wrong_response
          Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
        end

        def dishonorable_response
          Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
        end

        def ineligible_service_response
          Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
        end

        def unknown_service_response
          Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE
        end

        def edipi_no_pnl_response
          Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE
        end

        def currently_serving_response
          Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
        end

        def error_response
          Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE
        end
      end
    end
  end
end
