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
        contact_preference
        is_question_about_veteran_or_someone_else
        more_about_your_relationship_to_veteran
        relationship_to_veteran
        relationship_not_listed
        select_category
        select_subtopic
        select_topic
        their_relationship_to_veteran
        they_have_relationship_not_listed
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
        # Directly coupling to Datadog::Trace is a bad idea, but this is a targetted change.
        # This is a temporary solution to avoid the need for a full refactor of Logservice.
        Datadog::Tracing.trace('ask_va_api.inquiries.creator.call') do |span|
          safe_fields = log_safe_fields_from_inquiry(inquiry_params)
          span.set_tag('user.isAuthenticated', user.present?)
          span.set_tag('user.loa', user&.loa&.fetch(:current, nil))

          payload = build_payload(inquiry_params)
          # put safe_fields in span for better observability
          span.set_tag('inquiry_context', safe_fields)
          post_data(payload)
        rescue => e
          span.set_error(e)
          raise InquiriesCreatorError, "InquiriesCreatorError: #{e.message}"
        end
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
    end
  end
end
