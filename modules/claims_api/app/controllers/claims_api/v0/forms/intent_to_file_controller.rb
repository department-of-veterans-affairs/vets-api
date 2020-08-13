# frozen_string_literal: true

require_dependency 'claims_api/base_form_controller'

module ClaimsApi
  module V0
    module Forms
      class IntentToFileController < ClaimsApi::BaseFormController
        skip_before_action(:authenticate)
        before_action :validate_json_format, if: -> { request.post? }
        before_action :validate_json_schema, only: %i[submit_form_0966 validate]

        FORM_NUMBER = '0966'

        def submit_form_0966
          bgs_response = bgs_service.intent_to_file.insert_intent_to_file(intent_to_file_options)
          render json: bgs_response,
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        def active
          bgs_response = bgs_service.intent_to_file.find_intent_to_file_by_ptcpnt_id_itf_type_cd(
            target_veteran.participant_id,
            ClaimsApi::IntentToFile::ITF_TYPES[active_param]
          )
          if bgs_response.present?
            render json: bgs_response&.first,
                   serializer: ClaimsApi::IntentToFileSerializer
          else
            render json: itf_not_found, status: :not_found
          end
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
