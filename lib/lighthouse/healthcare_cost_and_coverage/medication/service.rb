# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module Medication
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.medication'

        def initialize(icn)
          @icn = icn
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?

          super()
        end

        def list(id:, **params)
          endpoint = 'r4/Medication'
          query = { _id: id }

          query.merge!(params) if params.present?
          config.get(endpoint, params: query, icn: @icn).body
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
