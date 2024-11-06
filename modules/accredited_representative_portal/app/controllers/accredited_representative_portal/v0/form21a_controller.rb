# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    # Form21aController handles the submission of Form 21a to the accreditation service.
    # It parses the request body, submits the form via AccreditationService, and processes the response.
    class Form21aController < ApplicationController
      class SchemaValidationError < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Validation failed: #{errors}")
        end
      end

      FORM_ID = '21a'

      before_action :parse_request_body, :validate_schema, only: [:submit]

      # Parses the request body and submits the form.
      # Renders the appropriate response based on the service's outcome.
      def submit
        response = AccreditationService.submit_form21a(parsed_request_body, @current_user&.uuid)

        InProgressForm.form_for_user(FORM_ID, @current_user)&.destroy if response.success?
        render_ogc_service_response(response)
      end

      private

      attr_reader :parsed_request_body

      def schema
        # NOTE: This doesn't reject any extra attributes not found in the schema. If
        # we want that the schema needs to have { "additionalProperties" => false }
        VetsJsonSchema::SCHEMAS[FORM_ID.upcase]
      end

      # Parses the raw request body as JSON and assigns it to an instance variable.
      # Renders a bad request response if the JSON is invalid.
      def parse_request_body
        @parsed_request_body = JSON.parse(request.raw_post)
      rescue JSON::ParserError
        handle_json_error
      end

      def validate_schema
        errors = JSON::Validator.fully_validate(schema, parsed_request_body)
        raise SchemaValidationError, errors if errors.any?
      rescue SchemaValidationError => e
        handle_json_error(e.errors.join(', ').squeeze(' '))
      end

      def handle_json_error(details = nil)
        error_message = 'Form21aController: Invalid JSON in request body for user ' \
                        "with user_uuid=#{@current_user&.uuid}."
        error_message += " Errors: #{details}" if details

        Rails.logger.error(error_message)
        render json: { errors: 'Invalid JSON' }, status: :bad_request
      end

      # Renders the response based on the service call's success or failure.
      def render_ogc_service_response(response)
        if response.success?
          Rails.logger.info(
            'Form21aController: Form 21a successfully submitted to OGC service ' \
            "by user with user_uuid=#{@current_user&.uuid} - Response: #{response.body}"
          )
          render json: response.body, status: response.status
        elsif response.body.blank?
          Rails.logger.info(
            "Form21aController: Blank response from OGC service for user with user_uuid=#{@current_user&.uuid}"
          )
          render status: :no_content
        else
          Rails.logger.error(
            'Form21aController: Failed to parse response from external OGC service ' \
            "for user with user_uuid=#{@current_user&.uuid}"
          )
          render json: { errors: 'Failed to parse response' }, status: :bad_gateway
        end
      end
    end
  end
end
