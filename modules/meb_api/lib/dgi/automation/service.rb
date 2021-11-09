# frozen_string_literal: true

require 'dgi/automation/configuration'
require 'dgi/service'
require 'common/client/base'
require 'authentication_token_service'

module MebApi
  module DGI
    module Automation
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Automation::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.automation'

        def post_claimant_info(json)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            perform(:post, end_point, json, headers, options)
          end
        end

        private

        def end_point
          'claimType/Chapter33/claimants'
        end

        def json
          # Passes Back User SSN in the Re body
          # { "ssn": '539139735' }

          nil
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
