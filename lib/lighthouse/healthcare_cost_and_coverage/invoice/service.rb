# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module Invoice
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.invoice'

        def initialize(icn)
          @icn = icn
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?

          super()
        end

        def list(count: 10, page: 1, id: nil, **extra)
          endpoint = 'r4/Invoice'
          params = { patient: @icn, _count: count, page: }.merge(extra)
          params[:_id] = id if id

          config.get(endpoint, params:, icn: @icn).body
        rescue Faraday::TimeoutError, Faraday::ClientError, Faraday::ServerError => e
          handle_error(e, endpoint)
        end

        def read(id)
          raise ArgumentError, 'no ID passed in for HCCC Invoice read request' if id.blank?

          endpoint = "r4/Invoice/#{id}"

          config.get(endpoint, icn: @icn).body
        rescue Faraday::TimeoutError, Faraday::ClientError, Faraday::ServerError => e
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
