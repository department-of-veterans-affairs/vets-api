# frozen_string_literal: true

require 'common/client/base'
require 'dgi/forms/configuration/configuration'
require 'dgi/forms/service/submission_service'
require 'dgi/submission/submission_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Forms
      class SubmissionService < MebApi::DGI::Service
        configuration MebApi::DGI::Submission::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.submission'

        def submit_claim(params, form_type)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, end_point(form_type), format_params(params), headers, options)

            MebApi::DGI::Submission::SubmissionResponse.new(response.status, response)
          end
        end

        private

        def end_point(form_type)
          "claimType/#{form_type}/claimsubmission"
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
