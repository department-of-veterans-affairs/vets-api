# frozen_string_literal: true

require 'common/client/base'
require 'dgi/forms/configuration/configuration'
require 'dgi/service'
require 'dgi/forms/response/sponsor_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Forms
      module Sponsor
        class Service < MebApi::DGI::Service
          configuration MebApi::DGI::Forms::Configuration
          STATSD_KEY_PREFIX = 'api.dgi.fry_dea'

          def post_sponsor(form_type = 'toe')
            with_monitoring do
              options = { timeout: 60 }
              response = perform(:post, sponsor_end_point(form_type), { ssn: @user.ssn }.to_json, headers, options)

              MebApi::DGI::Forms::Response::SponsorResponse.new(response)
            end
          end

          private

          def sponsor_end_point(form_type)
            "claimType/#{form_type}/claimants/sponsors"
          end

          def headers
            {
              Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
            }
          end
        end
      end
    end
  end
end
