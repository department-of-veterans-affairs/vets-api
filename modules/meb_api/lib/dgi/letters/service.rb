# frozen_string_literal: true

require 'common/client/base'
require 'dgi/letters/configuration'
require 'dgi/service'
require 'authentication_token_service'

module MebApi
  module DGI
    module Letters
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Letters::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_claim_letter(claimant_id, type = 'Chapter33')
          type ||= 'Chapter33'

          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            perform(:get, end_point(claimant_id, type), {}, headers, options)
          end
        end

        private

        def end_point(claimant_id, type)
          "claimant/#{claimant_id}/claimType/#{type}/letter"
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
