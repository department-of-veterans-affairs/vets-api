# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module Patient
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.patient'

        def initialize(icn)
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?

          @icn = icn

          super()
        end

        def read(id)
          raise ArgumentError, 'no ID passed in for HCCC Patient request' if id.blank?

          endpoint = 'r4/Patient'
          params = { _id: id }

          config.get(endpoint, params:, icn: @icn).body
        rescue Faraday::TimeoutError, Faraday::ClientError, Faraday::ServerError, Faraday::ParsingError => e
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
