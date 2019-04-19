# frozen_string_literal: true

require_dependency 'claims_api/intent_to_file_serializer'

module ClaimsApi
  module V1
    module Forms
      class IntentToFileController < BaseFormController
        before_action { permit_scopes %w[claim.write] }

        FORM_NUMBER = '0966'
        def submit_form_0966
          response = service.create_intent_to_file(form_type)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        def active
          response = service.get_active(form_type)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        private

        def service
          EVSS::IntentToFile::Service.new(target_veteran)
        end

        def form_type
          if !form_attributes.empty?
            form_attributes['type']
          else
            'compensation'
          end
        end

        def validate_json_schema
          # to support default compensation
          super unless form_attributes.empty?
        end
      end
    end
  end
end
