# frozen_string_literal: true

require 'common/client/base'
require 'dgib/authentication_token_service'
require 'dgib/service'
require 'dgib/claimant_lookup/configuration'
require 'dgib/claimant_lookup/response'

module Vye
  module DGIB
    module ClaimantLookup
      class Service < Vye::DGIB::Service
        configuration Vye::DGIB::ClaimantLookup::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.claimant_lookup_service'

        def claimant_lookup(ssn)
          params = ActionController::Parameters.new({ ssn: })
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, end_point, camelize_keys_for_java_service(params).to_json, headers, options)
            Vye::DGIB::ClaimantLookup::Response.new(response.status, response)
          end
        end

        private

        def end_point
          'dgi/vye/claimantLookup'
        end

        def json
          nil
        end

        def request_headers
          { Authorization: "Bearer #{DGIB::AuthenticationTokenService.call}" }
        end
      end
    end
  end
end
