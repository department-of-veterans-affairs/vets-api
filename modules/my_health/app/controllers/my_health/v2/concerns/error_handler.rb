# frozen_string_literal: true

module MyHealth
  module V2
    module Concerns
      module ErrorHandler
        extend ActiveSupport::Concern

        private

        # Main error handling orchestrator
        # @param error [Exception] The error to handle
        # @param resource_name [String] The name of the resource (e.g., 'clinical notes', 'vitals')
        # @param api_type [String] The API type ('FHIR' or 'SCDF')
        # @param use_dynamic_status [Boolean] Whether to use dynamic HTTP status based on error status (default: false)
        # @param include_backtrace [Boolean] Whether to include backtrace in logs (default: false)
        def handle_error(error, resource_name: nil, api_type: 'FHIR', use_dynamic_status: false,
                         include_backtrace: false)
          log_error(error, resource_name:, api_type:, include_backtrace:)

          case error
          when Common::Client::Errors::ClientError
            handle_client_error(error, api_type, use_dynamic_status:)
          when Common::Exceptions::BackendServiceException
            render json: { errors: error.errors }, status: :bad_gateway
          else
            handle_generic_error(resource_name)
          end
        end

        # Logs errors with contextual information
        # @param error [Exception] The error to log
        # @param resource_name [String] The name of the resource
        # @param api_type [String] The API type ('FHIR' or 'SCDF')
        # @param include_backtrace [Boolean] Whether to include backtrace in logs
        def log_error(error, resource_name: nil, api_type: 'FHIR', include_backtrace: false)
          message = case error
                    when Common::Client::Errors::ClientError
                      "#{resource_name} #{api_type} API error: #{error.message}"
                    when Common::Exceptions::BackendServiceException
                      "Backend service exception: #{error.errors.first&.detail}"
                    else
                      "Unexpected error in #{resource_name} controller: #{error.message}"
                    end

          Rails.logger.error(message)

          return unless include_backtrace && error.backtrace

          Rails.logger.error("Backtrace: #{error.backtrace.first(10).join("\n")}")
        end

        # Renders a standardized error response
        # @param title [String] The error title
        # @param detail [String] The error detail message
        # @param code [String] The error code
        # @param status [Integer, String] The status code
        # @param http_status [Symbol] The HTTP status symbol
        def render_error(title, detail, code, status, http_status)
          error = {
            title:,
            detail:,
            code:,
            status:
          }
          render json: { errors: [error] }, status: http_status
        end

        # Handles Common::Client::Errors::ClientError
        # @param use_dynamic_status [Boolean] If true, converts error status to appropriate HTTP status symbol
        def handle_client_error(error, api_type = 'FHIR', use_dynamic_status: false)
          status_symbol = if use_dynamic_status && error.status.is_a?(Integer)
                            Rack::Utils::SYMBOL_TO_STATUS_CODE.key(error.status) || :bad_gateway
                          else
                            :bad_gateway
                          end

          render_error("#{api_type} API Error", error.message, error.status, error.status, status_symbol)
        end

        # Handles generic/unexpected errors
        def handle_generic_error(resource_name)
          detail_message = if resource_name
                             "An unexpected error occurred while retrieving #{resource_name}."
                           else
                             'An unexpected error occurred.'
                           end

          render_error('Internal Server Error', detail_message, '500', 500, :internal_server_error)
        end
      end
    end
  end
end
