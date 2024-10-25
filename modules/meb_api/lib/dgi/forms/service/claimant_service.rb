# frozen_string_literal: true

require 'common/client/base'
require 'dgi/forms/configuration/configuration'
require 'dgi/service'
require 'dgi/forms/response/claimant_info_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Forms
      module Claimant
        class Service < MebApi::DGI::Service
          configuration MebApi::DGI::Forms::Configuration
          STATSD_KEY_PREFIX = 'api.dgi.claimant'

          def get_claimant_info(type)
            type ||= 'toe'

            with_monitoring do
              headers = request_headers
              options = { timeout: 60 }
              raw_response = perform(:post, end_point(type), { ssn: @user.ssn.to_s }.to_json, headers, options)

              MebApi::DGI::Forms::ClaimantResponse.new(raw_response.status, raw_response)
            end
          end

          private

          def end_point(type)
            "claimType/#{type}/claimants"
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
end
