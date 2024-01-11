# frozen_string_literal: true

require 'common/client/base'
require 'dgi/service'
require 'dgi/exclusion_period/configuration'
require 'dgi/exclusion_period/response'
require 'authentication_token_service'

module MebApi
  module DGI
    module ExclusionPeriod
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::ExclusionPeriod::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.exclusion'

        def get_exclusion_periods(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }

            response = perform(:get, end_point(claimant_id), {}, headers, options)

            MebApi::DGI::ExclusionPeriod::Response.new(response)
          end
        end

        private

        def end_point(claimant_id)
          "claimant/exclusionperiodtypes/#{claimant_id}"
        end

        def request_headers
          {
            'Content-Type': 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
