# frozen_string_literal: true

require 'common/client/base'
require 'dgi/enrollment/configuration'
require 'dgi/enrollment/response'
require 'dgi/service'
require 'authentication_token_service'

module MebApi
  module DGI
    module Enrollment
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Enrollment::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_enrollment(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:get, enrollment_url(claimant_id), {}, headers, options)

            MebApi::DGI::Enrollment::Response.new(response)
          end
        end

        def submit_enrollment
          true
        end

        private

        def enrollment_url(claimant_id)
          "claimant/#{claimant_id}/enrollments"
        end

        def request_headers
          {
            "Content-Type": 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
