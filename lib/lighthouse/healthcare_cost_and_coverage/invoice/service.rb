# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module Invoice
      # HCCC Invoice resource client (FHIR R4)
      # Endpoints:
      #   GET /r4/Invoice?patient=<ICN>[&_count=N][&_id=<InvoiceId>]
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.invoice'

        def initialize(icn)
          @icn = icn
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?

          super()
        end

        # List/search Invoices for a patient
        #
        # @param count [Integer] page size (_count)
        # @param id [String, nil] filter by a specific invoice id via search (_id)
        # @param extra [Hash] any additional FHIR search params (e.g., date/status if added later)
        #
        # @return [Hash] FHIR Bundle
        def list(count: 50, id: nil, **extra)
          endpoint = 'r4/Invoice'
          params = { patient: @icn, _count: count }.merge(extra)
          params[:_id] = id if id

          config.get(endpoint, params:, icn: @icn).body
        rescue Faraday::TimeoutError
          raise Lighthouse::ServiceException.new({ status: 504 }), 'Lighthouse Error'
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle_error(e, endpoint)
        end

        private

        def handle_error(error, endpoint)
          Lighthouse::ServiceException.send_error(
            error,
            self.class.to_s.underscore,
            nil, # lighthouse_client_id not used in HCCC
            "#{config.base_api_path}/#{endpoint}"
          )
        end
      end
    end
  end
end
