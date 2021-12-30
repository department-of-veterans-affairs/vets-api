# frozen_string_literal: true

require 'common/client/base'
require 'dgi/status/configuration'
require 'dgi/service'
require 'dgi/status/status_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Status
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Status::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_claim_status(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            raw_response = perform(:get, end_point(claimant_id), nil, headers, options)

            MebApi::DGI::Status::StatusResponse.new(raw_response.status, raw_response)
          end
        end

        private

        def end_point(claimant_id)
          "claimant/#{claimant_id}/claimType/Chapter33/claimstatus"
        end

        def request_headers
          {
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
