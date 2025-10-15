# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class Form21aController < ApplicationController
      skip_after_action :verify_pundit_authorization

      class SchemaValidationError < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Validation failed: #{errors}")
        end
      end

      FORM_ID = '21a'

      # NOTE: The order of before_action calls is important here.
      before_action :feature_enabled
      before_action :parse_request_body, :validate_form, only: [:submit]

      def details
        details_slug = params[:details_slug]
        Rails.logger.info("Received Form21a details submission for: #{details_slug}")

        # debugger
        render json: {
          data: {
            attributes: {
              confirmationCode: SecureRandom.uuid,
              name: params[:file].original_filename,
              size: params[:file].size,
              fileType: params[:file].content_type,
              # createdAt: Time.zone.now.iso8601
            }
          }
        }, status: :ok
      end

      def submit
        # debugger
        form_hash = JSON.parse(@parsed_request_body)

        begin
          response = AccreditationService.submit_form21a([form_hash], @current_user&.uuid)
          InProgressForm.form_for_user(FORM_ID, @current_user)&.destroy if response.success?
          render_ogc_service_response(response)
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          Rails.logger.error(
            "Form21aController: Network error: #{e.class} #{e.message} for user_uuid=#{@current_user&.uuid}"
          )
          render json: { errors: 'Service temporarily unavailable' }, status: :service_unavailable
        rescue => e
          Rails.logger.error(
            "Form21aController: Unexpected error: #{e.class} #{e.message} for user_uuid=#{@current_user&.uuid}"
          )
          render json: { errors: 'Internal server error' }, status: :internal_server_error
        end
      end

      private

      attr_reader :parsed_request_body

      def schema
        VetsJsonSchema::SCHEMAS[FORM_ID.upcase]
      end

      # Checks if the feature flag accredited_representative_portal_form_21a is enabled or not
      def feature_enabled
        routing_error unless Flipper.enabled?(:accredited_representative_portal_form_21a)
      end

      # Parses the raw request body as JSON and assigns it to an instance variable.
      # Renders a bad request response if the JSON is invalid.
      def parse_request_body
        raw = request.raw_post
        body = JSON.parse(raw)
        form_json = body.dig('form21aSubmission', 'form')
        raise JSON::ParserError, 'Missing or invalid form21aSubmission.form' unless form_json

        form_data = JSON.parse(form_json)
        form_data['icnNo'] = @current_user.icn if @current_user&.icn.present?
        form_data['uId']   = @current_user.uuid if @current_user&.uuid.present?
        @parsed_request_body = form_data.to_json
      rescue JSON::ParserError
        handle_json_error
      end

      def validate_form
        debugger
        errors = JSON::Validator.fully_validate(schema, @parsed_request_body)
        raise SchemaValidationError, errors if errors.any?
      rescue SchemaValidationError => e
        handle_json_error(e.errors.join(', ').squeeze(' '))
      end

      def handle_json_error(details = nil)
        error_message = 'Form21aController: Invalid JSON in request body for user ' \
                        "with user_uuid=#{@current_user&.uuid}."
        error_message += " Errors: #{details}" if details
        Rails.logger.error(error_message)

        response_error = details || 'Invalid JSON'
        render json: { errors: response_error }, status: :bad_request
      end

      def render_ogc_service_response(response)
        if response.success?
          # Upon successful form submission, extract the applicationId from the response body.
          # Use this applicationId to submit each attachment to GCLaws,
          # ensuring correct association with the original application.
          Rails.logger.info(
            'Form21aController: Form 21a successfully submitted to OGC service ' \
            "by user with user_uuid=#{@current_user&.uuid} - Response: #{response.body}"
          )
          render json: response.body, status: response.status
        elsif response.body.present?
          Rails.logger.error(
            "Form21aController: OGC service returned error response (status=#{response.status}) " \
            "for user with user_uuid=#{@current_user&.uuid}: #{response.body}"
          )
          render json: response.body, status: response.status
        else
          Rails.logger.error(
            'Form21aController: Blank or unparsable response from external OGC service ' \
            "for user with user_uuid=#{@current_user&.uuid}"
          )
          render status: :no_content
        end
      end
    end
  end
end
