# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/healthcare_cost_and_coverage/configuration'
require 'lighthouse/service_exception'

module Lighthouse
  module HealthcareCostAndCoverage
    module Account
      class Service < Common::Client::Base
        configuration Lighthouse::HealthcareCostAndCoverage::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.hccc.account'

        def initialize(icn)
          @icn = icn
          raise ArgumentError, 'no ICN passed in for HCCC request' if icn.blank?

          super()
        end

        # - If `id` is provided, the request is made with `?_id=<id>` and `patient` is ignored.
        # - Otherwise the request is made with `?patient=<patient>` (defaults to the ICN passed at initialize).
        # - Any extra `params` are merged into the query and may override `_id` or `patient` if keys collide.
        def list(id: nil, patient: @icn, **params)
          endpoint = 'r4/Account'
          query = {}

          if id
            query[:_id] = id
          else
            query[:patient] = patient
          end

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
