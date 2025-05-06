# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class SubmissionsController < ApplicationController
      skip_after_action :verify_pundit_authorization, only: :index

      def index
        authorize nil, policy_class: SubmissionPolicy
        render json: { data: demo_data, meta: pagination_meta(demo_data) }, status: :ok
      end

      private

      def pagination_meta(submissions)
        {
          page: {
            number: 1,
            size: 20,
            total: 45,
            totalPages: 3
          }
        }
      end

      def validated_params
        @validated_params ||= params_schema.validate_and_normalize!(params.to_unsafe_h)
      end

      def params_schema
        PowerOfAttorneyRequestService::ParamsSchema
      end

      def sort_params
        validated_params.fetch(:sort, {})
      end

      def page
        validated_params.dig(:page, :number)
      end

      def per_page
        validated_params.dig(:page, :size)
      end

      def demo_data
        [
          {
            "submittedDate": "2025-04-09",
            "firstName": "John",
            "lastName": "Snyder",
            "formType": "21-686c",
            "packet": true,
            "confirmationNumber": "e3bd5925-6902-4b94-acbc-49b554ffcec1",
            "vbmsStatus": "awaiting_receipt",
            "vbmsReceivedDate": "2025-04-19",
            "url": nil
          },
          {
            "submittedDate": "2025-04-09",
            "firstName": "Montgomery",
            "lastName": "Anderson",
            "formType": "21-686c",
            "packet": false,
            "confirmationNumber": "58d1c6a3-f970-48cb-bc92-65403e2a0c16",
            "vbmsStatus": "received",
            "vbmsReceivedDate": "2025-04-15",
            "url": nil
          },
          {
            "submittedDate": "2025-04-09",
            "firstName": "Isias",
            "lastName": "Fahey",
            "formType": "21-686c",
            "packet": false,
            "confirmationNumber": "f344d484-8b4b-4e81-93dc-5f6b6ef52bac",
            "vbmsStatus": "processing_error",
            "vbmsReceivedDate": "2025-04-15",
            "url": nil
          }
        ]
      end
    end
  end
end
