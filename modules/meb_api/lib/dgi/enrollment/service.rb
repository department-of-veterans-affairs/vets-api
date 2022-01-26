# frozen_string_literal: true

require 'common/client/base'
require 'dgi/enrollment/configuration'
require 'dgi/service'
require 'authentication_token_service'

module MebApi
  module DGI
    module Enrollment
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Enrollment::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_enrollment
          true
        end

        private

        def request_headers
          {
            "Accept": 'application/pdf',
            "Authorization": "Bearer #{MebApi::AuthenticationTokenService.call}",
            "Accept-Encoding": 'gzip, deflate, br',
            "Connection": 'keep-alive'
          }
        end
      end
    end
  end
end
