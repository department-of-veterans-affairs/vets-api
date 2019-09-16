# frozen_string_literal: true

require_dependency 'claims_api/base_form_controller'
require_dependency 'claims_api/concerns/itf_verification'

module ClaimsApi
  module V0
    module Forms
      class IntentToFileController < ClaimsApi::BaseFormController
        FORM_NUMBER = '0966'
        prepend_before_action :verify_loa, :log_request
        include ClaimsApi::ItfVerification

        skip_before_action(:authenticate)
        before_action :validate_json_schema, only: %i[submit_form_0966]
        before_action :check_future_type, only: [:submit_form_0966]

        FORM_NUMBER = '0966'

        def submit_form_0966
          response = itf_service.create_intent_to_file(form_type)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        def active
          response = itf_service.get_active(active_param)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        private

        def active_param
          params.require(:type)
        end

        def check_future_type
          unless form_type == 'compensation'
            error = {
              errors: [
                {
                  status: 422,
                  details: "#{form_type.titelize} claims are not currently supported, but will be in a future version"
                }
              ]
            }
            render json: error, status: 422
          end
        end

        def form_type
          form_attributes['type']
        end
      end
    end
  end
end
