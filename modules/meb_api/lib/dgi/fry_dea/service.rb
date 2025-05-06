# frozen_string_literal: true

require 'common/client/base'
require 'dgi/fry_dea/configuration'
require 'dgi/service'
require 'dgi/fry_dea/response'
require 'authentication_token_service'

module MebApi
  module DGI
    module FryDea
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::FryDea::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.fry_dea'

        def post_sponsor
          with_monitoring do
            options = { timeout: 60 }
            response = perform(:post, sponsors_end_point, { ssn: @user.ssn }.to_json, headers, options)

            MebApi::DGI::FryDea::Response.new(response)
          end
        end

        private

        def sponsors_end_point
          'claimType/FryDea/claimants/sponsors'
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
