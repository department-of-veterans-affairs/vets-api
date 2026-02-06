# frozen_string_literal: true

module Vass
  # Base controller for all VASS API endpoints
  # Inherits from ::ApplicationController which provides ExceptionHandling, Headers, and other concerns
  #
  # PHI SAFETY: All error handlers use static messages only. Never log or render exception.message
  # as it may contain patient health information. Only log safe context: error type, class, action.
  class ApplicationController < ::ApplicationController
    include Vass::Logging

    service_tag 'vass'

    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    # Handle CORS preflight requests
    def cors_preflight
      head :ok
    end

    # Catch-all for unexpected errors to ensure they're logged to Rails.logger
    # (and therefore Datadog Logs) before the global handler processes them.
    # This addresses a gap where errors may only go to Sentry if configured.
    # NOTE: Must be declared FIRST so it runs LAST (rescue_from uses reverse order)
    rescue_from StandardError, with: :handle_unexpected_error

    # Custom rescue_from handlers for VASS-specific errors
    # Note: RateLimitError and VANotify::Error are handled locally in SessionsController
    rescue_from Vass::Errors::AuthenticationError, with: :handle_authentication_error
    rescue_from Vass::Errors::NotFoundError, with: :handle_not_found_error
    rescue_from Vass::Errors::ServiceError, with: :handle_service_error
    rescue_from Vass::Errors::VassApiError, with: :handle_vass_api_error
    rescue_from Vass::Errors::RedisError, with: :handle_redis_error
    rescue_from Vass::Errors::AuditLogError, with: :handle_audit_log_error
    rescue_from Vass::Errors::SerializationError, with: :handle_serialization_error

    private

    def handle_authentication_error(exception)
      log_safe_error('authentication_error', exception.class.name)
      detail = safe_auth_error_message(exception.message)
      render_error_response(
        title: 'Authentication Error',
        detail:,
        code: 'unauthorized',
        status: :unauthorized
      )
    end

    # Returns the exception message only if it's in the whitelist of safe messages.
    # Falls back to generic message to prevent accidental PII leakage.
    def safe_auth_error_message(message)
      return message if Vass::Errors::AuthenticationError::SAFE_MESSAGES.include?(message)

      'Unable to authenticate request'
    end

    def handle_not_found_error(exception)
      log_safe_error('not_found', exception.class.name)
      render_error_response(
        title: 'Not Found',
        detail: 'Appointment not found',
        code: 'appointment_not_found',
        status: :not_found
      )
    end

    def handle_service_error(exception)
      log_safe_error('service_error', exception.class.name)
      render_error_response(
        title: 'Service Error',
        detail: 'The service is temporarily unavailable',
        code: 'service_error',
        status: :service_unavailable
      )
    end

    def handle_vass_api_error(exception)
      log_safe_error('vass_api_error', exception.class.name)
      render_error_response(
        title: 'VASS API Error',
        detail: 'Unable to process request with appointment service',
        code: 'vass_api_error',
        status: :bad_gateway
      )
    end

    def handle_redis_error(exception)
      log_safe_error('redis_error', exception.class.name)
      render_error_response(
        title: 'Service Unavailable',
        detail: 'The service is temporarily unavailable. Please try again later.',
        code: 'service_unavailable',
        status: :service_unavailable
      )
    end

    def handle_audit_log_error(exception)
      log_safe_error('audit_log_error', exception.class.name)
      render_error_response(
        title: 'Internal Server Error',
        detail: 'Unable to complete request due to an internal error',
        code: 'audit_log_error',
        status: :internal_server_error
      )
    end

    def handle_serialization_error(exception)
      log_safe_error('serialization_error', exception.class.name)
      render_error_response(
        title: 'Internal Server Error',
        detail: 'Unable to complete request due to an internal error',
        code: 'serialization_error',
        status: :internal_server_error
      )
    end

    def handle_unexpected_error(exception)
      log_vass_event(
        action: action_name,
        level: :error,
        error_type: 'unexpected_error',
        error_class: exception.class.name
      )
      raise exception # Re-raise so global handler still processes the error
    end

    # Logs error information without PHI
    # Only logs: error type, exception class, controller, action, status, timestamp
    def log_safe_error(error_type, exception_class)
      log_vass_event(
        action: action_name,
        level: :error,
        error_type:,
        exception_class:
      )
    end

    # Render error response in JSON:API format
    def render_error_response(title:, detail:, status:, code: nil)
      status_code = Rack::Utils.status_code(status)
      error_code = code || status_code.to_s
      render json: {
        errors: [{
          title:,
          detail:,
          code: error_code
        }]
      }, status:
    end

    ##
    # Validates that required parameters are present.
    # Raises ActionController::ParameterMissing if any parameter is missing.
    # Available to all VASS controllers.
    #
    # @param param_names [Array<Symbol>] Parameter names to validate
    # @raise [ActionController::ParameterMissing] if any parameter is missing
    #
    # @example Validate single parameter
    #   validate_required_params!(:appointment_id)
    #
    # @example Validate multiple parameters
    #   validate_required_params!(:topics, :dtStartUtc, :dtEndUtc)
    #
    # @example Validate nested parameters
    #   session_params = params.require(:session)
    #   validate_required_params_in!(session_params, :uuid, :last_name, :dob)
    #
    def validate_required_params!(*param_names)
      param_names.each { |param| params.require(param) }
    end

    ##
    # Validates that required parameters are present in a nested parameter hash.
    # Raises ActionController::ParameterMissing if any parameter is missing.
    #
    # @param param_hash [ActionController::Parameters] Nested parameter hash
    # @param param_names [Array<Symbol>] Parameter names to validate
    # @raise [ActionController::ParameterMissing] if any parameter is missing
    #
    def validate_required_params_in!(param_hash, *param_names)
      param_names.each { |param| param_hash.require(param) }
    end

    ##
    # Renders JSON response with keys transformed to camelCase for frontend API contract.
    # Maintains Rails snake_case conventions internally while providing camelCase externally.
    #
    # @param data [Hash, Array] Data to render (keys will be camelized)
    # @param status [Symbol] HTTP status symbol (defaults to :ok)
    #
    def render_camelized_json(data, status: :ok)
      render json: camelize_keys(data), status:
    end

    ##
    # Recursively transforms hash keys from snake_case to camelCase.
    # Handles nested hashes and arrays. Non-hash/array values pass through unchanged.
    #
    # @param obj [Object] Object to transform (Hash, Array, or other)
    # @return [Object] Transformed object with camelized keys, or nil if input is nil
    # @raise [Vass::Errors::SerializationError] if transformation fails
    #
    def camelize_keys(obj)
      return nil if obj.nil?

      case obj
      when Hash
        obj.transform_keys { |key| key.to_s.camelize(:lower) }
           .transform_values { |value| camelize_keys(value) }
      when Array
        obj.map { |item| camelize_keys(item) }
      else
        obj
      end
    rescue Encoding::UndefinedConversionError, TypeError, NoMethodError => e
      raise Vass::Errors::SerializationError, "Failed to serialize response: #{e.class.name}"
    end
  end
end
