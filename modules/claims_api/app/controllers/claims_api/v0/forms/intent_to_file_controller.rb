# frozen_string_literal: true

require 'claims_api/intent_to_file_serializer'

module ClaimsApi
  module V0
    module Forms
      class IntentToFileController < ApplicationController
        skip_before_action(:authenticate)

        before_action :validate_json_api_payload

        def submit_form_0966
          response = service.create_intent_to_file(form_type)
          render json: response['intent_to_file'],
                 serializer: ClaimsApi::IntentToFileSerializer
        end

        private

        def service
          EVSS::IntentToFile::Service.new(target_veteran)
        end

        def attributes
          if request.body.string.present?
            JSON.parse(request.body.string).dig('data', 'attributes')
          else
            {}
          end
        end

        def form_type
          if !attributes.empty?
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

        def target_veteran
          @target_veteran ||= ClaimsApi::Veteran.from_headers(request.headers)
        end
      end
    end
  end
end
