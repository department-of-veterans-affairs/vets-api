# frozen_string_literal: true

require 'claims_api/intent_to_file_serializer'

module ClaimsApi
  module V0
    module Forms
      class IntentToFileController < BaseFormController
        skip_before_action(:authenticate)
        skip_before_action(:verify_power_of_attorney)

        def submit_form_0966
          response = service.create_intent_to_file(form_type)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        private

        def service
          EVSS::IntentToFile::Service.new(target_veteran)
        end

        def form_type
          if !form_attributes.empty?
            attributes['type']
          else
            'compensation'
          end
        end

        def validate_json_api_payload
          unless attributes.empty?
            # validate
          end
        end
      end
    end
  end
end
