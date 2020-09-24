# frozen_string_literal: true

require_dependency 'claims_api/intent_to_file_serializer'
require_dependency 'claims_api/concerns/poa_verification'
require 'evss/intent_to_file/service'

module ClaimsApi
  module V1
    module Forms
      class IntentToFileController < BaseFormController
        include ClaimsApi::PoaVerification

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_0966 validate]
        before_action :check_for_type, only: %i[active]

        FORM_NUMBER = '0966'
        ITF_TYPES = %w[compensation pension burial].freeze

        def submit_form_0966
          bgs_response = bgs_service.intent_to_file.insert_intent_to_file(intent_to_file_options)
          render json: bgs_response,
                 serializer: ClaimsApi::IntentToFileSerializer
        rescue Savon::SOAPFault => e
          error = {
            errors: [
              {
                status: 422,
                details: e.message&.split('>')&.last
              }
            ]
          }
          render json: error, status: :unprocessable_entity
        end

        def active
          bgs_response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES[active_param]
          )
          if bgs_response.is_a?(Array)
            bgs_active = bgs_response.detect do |itf|
              active?(itf)
            end
          elsif active?(bgs_response)
            bgs_active = bgs_response
          end

          if bgs_active.present?
            render json: bgs_active, serializer: ClaimsApi::IntentToFileSerializer
          else
            render json: itf_not_found, status: :not_found
          end
        end

        def validate
          render json: validation_success
        end

        private

        def active?(itf)
          itf.present? && itf[:itf_status_type_cd] == 'Active' && itf[:exprtn_dt].to_datetime > Time.zone.now
        end

        def active_param
          params.require(:type)
        end

        def check_for_type
          if active_param && !ITF_TYPES.include?(active_param)
            error = {
              errors: [
                {
                  status: 422,
                  details: "Must include either compensation, pension or burial as a 'type' parameter."
                }
              ]
            }
            render json: error, status: :unprocessable_entity
          end
        end

        def form_type
          form_attributes['type']
        end

        def validation_success
          {
            data: {
              type: 'intentToFileValidation',
              attributes: {
                status: 'valid'
              }
            }
          }
        end
      end
    end
  end
end
