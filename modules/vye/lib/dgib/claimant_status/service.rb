# frozen_string_literal: true

require 'common/client/base'
require 'dgib/authentication_token_service'
require 'dgib/service'
require 'dgib/claimant_status/configuration'
require 'dgib/claimant_status/response'

module Vye
  module DGIB
    module ClaimantStatus
      class Service < Vye::DGIB::Service
        configuration Vye::DGIB::ClaimantStatus::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.claimant_status_service'

        def get_claimant_status(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            raw_response = perform(:get, end_point(claimant_id), {}, headers, options)
            Vye::DGIB::ClaimantStatus::Response.new(raw_response.status, raw_response)
          end
        end

        private

        def end_point(claimant_id)
          "verifications/vye/#{claimant_id}/status"
        end

        def json
          nil
        end

        def request_headers
          {
            Authorization: "Bearer #{DGIB::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
