# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiriesCreatorError < StandardError
      attr_reader :context

      def initialize(message = nil, context: {})
        super(message)
        @context = context
      end

      def to_h
        {
          error: message,
          safe_fields: context[:safe_fields]
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end
    end

    class Creator
      ENDPOINT = 'inquiries/new'
      SAFE_INQUIRY_FIELDS = %i[
        about_your_relationship_to_family_member
        category_id
        contact_preference
        family_members_location_of_residence
        family_member_postal_code
        is_question_about_veteran_or_someone_else
        more_about_your_relationship_to_veteran
        relationship_to_veteran
        relationship_not_listed
        select_category
        select_subtopic
        select_topic
        state_of_property
        subtopic_id
        their_relationship_to_veteran
        they_have_relationship_not_listed
        topic_id
        veterans_postal_code
        veterans_location_of_residence
        who_is_your_question_about
        your_location_of_residence
        your_role
        your_role_education
      ].freeze

      attr_reader :user, :service

      def initialize(user:, service: nil)
        @user = user
        @service = service || default_service
      end

      def call(inquiry_params:)
        payload = build_payload(inquiry_params)
        post_data(payload)
      rescue => e
        safe_fields = log_safe_fields_from_inquiry(inquiry_params)
        # Raise with error context for downstream logging/rendering
        raise InquiriesCreatorError.new(
          "InquiriesCreatorError: #{e.message}",
          context: {
            safe_fields:
          }
        )
      end

      private

      def log_safe_fields_from_inquiry(inquiry_params)
        inquiry_params.slice(*SAFE_INQUIRY_FIELDS)
      end

      def default_service
        Crm::Service.new(icn: user&.icn)
      end

      def build_payload(inquiry_params)
        PayloadBuilder::InquiryPayload.new(inquiry_params:, user:).call
      end

      def post_data(payload)
        response = service.call(endpoint: ENDPOINT, method: :put, payload:)
        handle_response(response)
      end

      def handle_response(response)
        response.is_a?(Hash) ? response[:Data] : raise(InquiriesCreatorError, response.body)
      end

      def handle_error(error)
        ErrorHandler.handle_service_error(error)
      end
    end
  end
end
