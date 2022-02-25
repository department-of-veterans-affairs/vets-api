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

        def submit_enrollment(params)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, submit_enrollment_url, format_params(params), headers, options)

            MebApi::DGI::Enrollment::Response.new(response)
          end
        end

        private

        def enrollment_url(claimant_id)
          "claimant/#{claimant_id}/enrollments"
        end

        def submit_enrollment_url
          'enrollmentverification'
        end

        def request_headers
          {
            "Content-Type": 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end

        def format_params(params)
          camelize_keys_for_java_service(params)
        end

        def camelize_keys_for_java_service(params)
          params.permit!.to_h.deep_transform_keys do |key|
            if key.include?('_')
              split_keys = key.split('_')
              split_keys.collect { |key_part| split_keys[0] == key_part ? key_part : key_part.capitalize }.join
            else
              key
            end
          end
        end
      end
    end
  end
end
