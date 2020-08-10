# frozen_string_literal: true

require_dependency 'claims_api/intent_to_file_serializer'
require_dependency 'claims_api/concerns/poa_verification'

module ClaimsApi
  module V1
    module Forms
      class IntentToFileController < BaseFormController
        include ClaimsApi::PoaVerification

        before_action { permit_scopes %w[claim.write] }
        before_action :validate_json_schema, only: %i[submit_form_0966 validate]

        FORM_NUMBER = '0966'
        def submit_form_0966
          response = bgs_service.intent_to_file.insert_intent_to_file(intent_to_file_options)
          render json: response,
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        def active
          bgs_response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES[active_param]
          )&.first
          render json: bgs_response,
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        def validate
          render json: validation_success
        end

        private

        def active_param
          params.require(:type)
        end

        def form_type
          form_attributes['type']
        end
<<<<<<< HEAD
=======

        def itf_service
          EVSS::IntentToFile::Service.new(target_veteran)
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
>>>>>>> 3a29d31de4d6c9cfca0951ce0acb51e7ffefcd32
      end
    end
  end
end
