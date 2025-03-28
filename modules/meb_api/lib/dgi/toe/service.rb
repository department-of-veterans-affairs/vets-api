# frozen_string_literal: true

require 'common/client/base'
require 'dgi/letters/configuration'
require 'dgi/toe/configuration'
require 'dgi/service'
require 'authentication_token_service'

module MebApi
  module DGI
    module Toe
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Letters::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_toe_letter(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            perform(:get, end_point(claimant_id), {}, headers, options)
          end
        end

        private

        def end_point(claimant_id)
          # Enable this after other team has finished creating this endpoint.
          # "claimant/#{claimant_id}/claimType/toe/letter"

          "claimant/#{claimant_id}/claimType/Chapter33/letter"
        end

        def request_headers
          {
            Accept: 'application/pdf',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}",
            'Accept-Encoding': 'gzip, deflate, br',
            Connection: 'keep-alive'
          }
        end
      end
    end
  end
end
