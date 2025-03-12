# frozen_string_literal: true

require 'common/client/base'
require 'dgi/toe/sponsors_configuration'
require 'dgi/service'
require 'dgi/toe/sponsors_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Toe
      module Sponsor
        class Service < MebApi::DGI::Service
          configuration MebApi::DGI::Toe::Sponsor::Configuration
          STATSD_KEY_PREFIX = 'api.dgi.toe'

          def post_sponsor
            with_monitoring do
              options = { timeout: 60 }
              response = perform(:post, sponsors_end_point, { ssn: @user.ssn }.to_json, headers, options)

              MebApi::DGI::Toe::Response.new(response)
            end
          end

          private

          def sponsors_end_point
            'claimType/TOE/claimants/sponsors'
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
