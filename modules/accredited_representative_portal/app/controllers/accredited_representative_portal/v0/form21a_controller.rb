# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class Form21aController < ApplicationController
      include Logging

      skip_after_action :verify_pundit_authorization

      class SchemaValidationError < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Validation failed: #{errors}")
        end
      end

      FORM_ID = '21a'
      METRIC = 'form21a'

      before_action :parse_request_body, :validate_form, only: [:submit]

      def submit
        response = AccreditationService.submit_form21a(parsed_request_body, @current_user&.uuid)
        InProgressForm.form_for_user(FORM_ID, @current_user)&.destroy if response.success?
        render_ogc_service_response(response)
      end

      private

      attr_reader :parsed_request_body

      def schema
        VetsJsonSchema::SCHEMAS[FORM_ID.upcase]
      end

      def parse_request_body
        @parsed_request_body = JSON.parse(request.raw_post)
      rescue JSON::ParserError
        log_error('Invalid JSON in request body', "#{METRIC}.invalid_json")
        handle_json_error
      end

      def validate_form
        errors = JSON::Validator.fully_validate(schema, parsed_request_body)
        raise SchemaValidationError, errors if errors.any?
      rescue SchemaValidationError => e
        log_error('Schema validation failed', "#{METRIC}.schema_validation_error", nil,
                  user_tags(["errors:#{e.errors.join(';')}"]))
        handle_json_error(e.errors.join(', ').squeeze(' '))
      end

      def handle_json_error(details = nil)
        error_message = "Invalid JSON in request body for user #{user_tags}."
        error_message + " Errors: #{details}" if details
        render json: { errors: 'Invalid JSON' }, status: :bad_request
      end

      def render_ogc_service_response(response)
        if response.success?
          render json: response.body, status: response.status
        elsif response.body.blank?
          log_warn('Blank response from OGC service', "#{METRIC}.response.blank")
          render status: :no_content
        else
          log_error('Failed to parse OGC service response', "#{METRIC}.response.parse_error")
          render json: { errors: 'Failed to parse response' }, status: :bad_gateway
        end
      end
    end
  end
end
