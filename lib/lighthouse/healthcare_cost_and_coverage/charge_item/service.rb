# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module ChargeItem
      # HCCC ChargeItem resource client (FHIR R4)
      # Endpoints:
      #   GET /r4/ChargeItem?patient=<ICN>[&_count=N][&_id=<ChargeItemId>]
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.charge_item'

        def initialize(icn)
          @icn = icn
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?
          super()
        end

        # List/search ChargeItems for a patient
        #
        # @param count [Integer] page size (_count)
        # @param id [String, nil] filter by a specific charge item id via search (_id)
        # @param extra [Hash] any additional FHIR search params
        #
        # @return [Hash] FHIR Bundle
        def list(count: 50, id: nil, **extra)
          endpoint = 'r4/ChargeItem'
          params   = { patient: @icn, _count: count }.merge(extra)
          params[:_id] = id if id

          config.get(endpoint, params: params, icn: @icn).body
        rescue Faraday::TimeoutError, Faraday::ClientError, Faraday::ServerError => e
          handle_error(e, endpoint)
        end

        private

        def handle_error(error, endpoint)
          Lighthouse::ServiceException.send_error(
            error,
            self.class.to_s.underscore,
            nil,
            "#{config.base_api_path}/#{endpoint}"
          )
        end
      end
    end
  end
end
