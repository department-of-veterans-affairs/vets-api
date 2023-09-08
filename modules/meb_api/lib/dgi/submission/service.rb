# frozen_string_literal: true

require 'common/client/base'
require 'dgi/submission/configuration'
require 'dgi/service'
require 'dgi/submission/submit_claim_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Submission
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Submission::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.submission'

        def submit_claim(params)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, end_point, format_params(params), headers, options)

            MebApi::DGI::Submission::SubmissionResponse.new(response.status, response)
          end
        end

        private

        def end_point
          'claimType/Chapter33/claimsubmission'
        end

        def request_headers
          {
            "Content-Type": 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end

        def format_params(params)
          if Flipper.enabled?(:meb_gate_person_criteria)
            camelized_keys = camelize_keys_for_java_service(params.except(:form_id))
            modified_keys = camelized_keys['claimant']&.merge(
              personCriteria: { ssn: @user.ssn }.stringify_keys)
            camelized_keys['claimant'] = modified_keys
            camelized_keys
          else
            camelize_keys_for_java_service(params)
          end
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
