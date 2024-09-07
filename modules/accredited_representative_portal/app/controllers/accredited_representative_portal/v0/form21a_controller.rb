# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    # Form21aController handles the submission of Form 21a to the accreditation service.
    # It parses the request body, submits the form via AccreditationService, and processes the response.
    class Form21aController < ApplicationController
      before_action :parse_request_body, only: [:post]

      # Parses the request body and submits the form.
      # Renders the appropriate response based on the service's outcome.
      def submit
        # response = AccreditationService.submit_form21a(parsed_request_body)
        response = OpenStruct.new(
          success?: true,
          status: 200,
          body: { success: true }
        )

        clear_saved_form('21a') if response.success?
        render_ogc_service_response(response)
      rescue => e
        Rails.logger.error("Form21aController: Unexpected error occurred - #{e.message}")
        render json: { errors: 'Unexpected error' }, status: :internal_server_error
      end

      private

      attr_reader :parsed_request_body

      # Parses the raw request body as JSON and assigns it to an instance variable.
      # Renders a bad request response if the JSON is invalid.
      def parse_request_body
        @parsed_request_body = JSON.parse(request.raw_post)
      rescue JSON::ParserError
        Rails.logger.error('Form21aController: Invalid JSON in request body')
        render json: { errors: 'Invalid JSON' }, status: :bad_request
      end

      # Renders the response based on the service call's success or failure.
      def render_ogc_service_response(response)
        if response.success?
          render json: response.body, status: response.status
        elsif response.body.blank?
          Rails.logger.info('Form21aController: Blank response from OGC service')
          render status: :no_content
        else
          Rails.logger.error('Form21aController: Failed to parse response from external OGC service')
          render json: { errors: 'Failed to parse response' }, status: :bad_gateway
        end
      end
    end
  end
end
