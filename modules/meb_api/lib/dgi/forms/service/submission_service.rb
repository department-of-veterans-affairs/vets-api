# frozen_string_literal: true

require 'common/client/base'
require 'dgi/service'
require 'dgi/forms/configuration/configuration'
require 'dgi/forms/response/submission_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Forms
      module Submission
        class Service < MebApi::DGI::Service
          configuration MebApi::DGI::Submission::Configuration
          STATSD_KEY_PREFIX = 'api.dgi.submission'

          def submit_claim(params, form_type = 'toe')
            with_monitoring do
              headers = request_headers
              options = { timeout: 60 }
              response = perform(:post, end_point(form_type), format_params(params['form']), headers, options)

              MebApi::DGI::Forms::Submission::Response.new(response.status, response)
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
            camelized_keys = camelize_keys_for_java_service(params)
            modified_keys = camelized_keys['toeClaimant']&.merge(
              personCriteria: { ssn: @user.ssn }.stringify_keys)

            camelized_keys['toeClaimant'] = modified_keys
            camelized_keys
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
end
