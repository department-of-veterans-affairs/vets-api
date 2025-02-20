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

          def submit_claim(params, response_data)
            unmasked_params = update_dd_params(params, response_data)
            form_type = params['@type']
            with_monitoring do
              headers = request_headers
              options = { timeout: 60 }
              response = perform(:post, end_point(form_type), format_params(unmasked_params['form']), headers, options)

              MebApi::DGI::Forms::Submission::Response.new(response.status, response)
            end
          end

          private

          def end_point(form_type)
            "claimType/#{dgi_url(form_type)}/claimsubmission".dup
          end

          def dgi_url(form_type)
            if form_type == 'Chapter35Submission'
              'Chapter35'
            else
              'toe'
            end
          end

          def request_headers
            {
              'Content-Type': 'application/json',
              Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}".dup
            }
          end

          def format_params(params)
            camelized_keys = camelize_keys_for_java_service(params.except(:form_id))
            if params['@type'] == 'ToeSubmission'
              modified_keys = camelized_keys['toeClaimant']&.merge(
                personCriteria: { ssn: @user.ssn }.stringify_keys
              )

              camelized_keys['toeClaimant'] = modified_keys
            else
              modified_keys = camelized_keys['claimant']&.merge(
                personCriteria: { ssn: @user.ssn }.stringify_keys
              )

              camelized_keys['claimant'] = modified_keys
            end
            camelized_keys
          end

          def update_dd_params(params, dd_params)
            check_masking = params.dig(:form, :direct_deposit, :direct_deposit_account_number)&.include?('*')
            if check_masking && !Flipper.enabled?(:toe_light_house_dgi_direct_deposit, @current_user)
              params[:form][:direct_deposit][:direct_deposit_account_number] = dd_params[:dposit_acnt_nbr]&.dup
              params[:form][:direct_deposit][:direct_deposit_routing_number] = dd_params[:routng_trnsit_nbr]&.dup
            elsif check_masking && Flipper.enabled?(:toe_light_house_dgi_direct_deposit, @current_user)
              params[:form][:direct_deposit][:direct_deposit_account_number] =
                dd_params&.payment_account ? dd_params.payment_account[:account_number]&.dup : nil
              params[:form][:direct_deposit][:direct_deposit_routing_number] =
                dd_params&.payment_account ? dd_params.payment_account[:routing_number]&.dup : nil
            end
            params
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
