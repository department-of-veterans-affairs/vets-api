# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'decision_reviews/v1/service_exception'

module DecisionReviews
  module V1
    module Concerns
      ##
      # Shared error handling concern for Decision Reviews services.
      # Provides consistent error mapping, monitoring, logging, and schema validation.
      #
      module ErrorHandling
        extend ActiveSupport::Concern

        included do
          include Common::Client::Concerns::Monitoring
        end

        ERROR_MAP = {
          504 => Common::Exceptions::GatewayTimeout,
          503 => Common::Exceptions::ServiceUnavailable,
          502 => Common::Exceptions::BadGateway,
          500 => Common::Exceptions::ExternalServerInternalServerError,
          429 => Common::Exceptions::TooManyRequests,
          422 => Common::Exceptions::UnprocessableEntity,
          413 => Common::Exceptions::PayloadTooLarge,
          404 => Common::Exceptions::ResourceNotFound,
          403 => Common::Exceptions::Forbidden,
          401 => Common::Exceptions::Unauthorized,
          400 => Common::Exceptions::BadRequest
        }.freeze

        private

        ##
        # Wraps a block with monitoring and error handling
        #
        # @yield The block to execute with monitoring
        # @return [Object] The result of the block
        #
        def with_monitoring_and_error_handling(&)
          with_monitoring(2, &)
        rescue => e
          handle_error(error: e)
        end

        ##
        # Saves error details to PersonalInformationLog for debugging
        #
        # @param error [Exception] The error to save
        #
        def save_error_details(error)
          PersonalInformationLog.create!(
            error_class: "#{self.class.name}#save_error_details exception #{error.class} (DECISION_REVIEW_V1)",
            data: { error: Class.new.include(FailedRequestLoggable).exception_hash(error) }
          )
        end

        ##
        # Logs error details to Rails logger
        #
        # @param error [Exception] The error to log
        # @param message [String] Optional message to include
        #
        def log_error_details(error:, message: nil)
          info = {
            message:,
            error_class: error.class,
            error:
          }
          ::Rails.logger.info(info)
        end

        ##
        # Builds log params for error scenarios
        #
        # @param error [Exception] The error to extract params from
        # @return [Hash] Log parameters
        #
        def error_log_params(error)
          log_params = { is_success: false, response_error: error }
          log_params[:body] = error.body if error.try(:status) == 422
          log_params
        end

        ##
        # Handles errors by saving, logging, and re-raising appropriate exceptions
        #
        # @param error [Exception] The error to handle
        # @param message [String] Optional message to include
        # @raise [Exception] The mapped exception
        #
        def handle_error(error:, message: nil)
          save_and_log_error(error:, message:)
          source_hash = { source: "#{error.class} raised in #{self.class}" }

          raise case error
                when Faraday::ParsingError
                  DecisionReviews::V1::ServiceException.new key: 'DR_502', response_values: source_hash
                when Common::Client::Errors::ClientError
                  error_status = error.status

                  if ERROR_MAP.key?(error_status)
                    ERROR_MAP[error_status].new(source_hash.merge(detail: error.body))
                  elsif error_status == 403
                    Common::Exceptions::Forbidden.new source_hash
                  else
                    DecisionReviews::V1::ServiceException.new(key: "DR_#{error_status}", response_values: source_hash,
                                                              original_status: error_status, original_body: error.body)
                  end
                else
                  error
                end
        end

        ##
        # Saves and logs error details
        #
        # @param error [Exception] The error to save and log
        # @param message [String] Optional message to include
        #
        def save_and_log_error(error:, message:)
          save_error_details(error)
          log_error_details(error:, message:)
        end

        ##
        # Validates JSON response against a schema
        #
        # @param json [Hash] The JSON to validate
        # @param schema [Hash] The schema to validate against
        # @param append_to_error_class [String] String to append to error class for identification
        # @raise [Common::Exceptions::SchemaValidationErrors] If validation fails
        #
        def validate_against_schema(json:, schema:, append_to_error_class: '')
          errors = JSONSchemer.schema(schema).validate(json).to_a
          return if errors.empty?

          raise Common::Exceptions::SchemaValidationErrors, remove_pii_from_json_schemer_errors(errors)
        rescue => e
          PersonalInformationLog.create!(
            error_class: "#{self.class.name}#validate_against_schema exception #{e.class}#{append_to_error_class}",
            data: {
              json:, schema:, errors:,
              error: Class.new.include(FailedRequestLoggable).exception_hash(e)
            }
          )
          raise
        end

        ##
        # Raises schema error if response status is not 200
        #
        # @param status [Integer] The HTTP status code
        # @raise [Common::Exceptions::SchemaValidationErrors] If status is not 200
        #
        def raise_schema_error_unless_200_status(status)
          return if status == 200

          raise Common::Exceptions::SchemaValidationErrors, ["expecting 200 status received #{status}"]
        end

        ##
        # Removes PII from JSON schema validation errors
        #
        # @param errors [Array] The validation errors
        # @return [Array] Errors with PII removed
        #
        def remove_pii_from_json_schemer_errors(errors)
          errors.map { |error| error.slice 'data_pointer', 'schema', 'root_schema' }
        end
      end
    end
  end
end
