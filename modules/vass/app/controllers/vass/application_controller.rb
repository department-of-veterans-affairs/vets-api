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

    # Custom rescue_from handlers for VASS-specific errors
    rescue_from Vass::Errors::AuthenticationError, with: :handle_authentication_error
    rescue_from Vass::Errors::NotFoundError, with: :handle_not_found_error
    rescue_from Vass::Errors::ValidationError, with: :handle_validation_error
    rescue_from Vass::Errors::ServiceError, with: :handle_service_error
    rescue_from Vass::Errors::VassApiError, with: :handle_vass_api_error
    rescue_from Vass::Errors::RedisError, with: :handle_redis_error
    rescue_from Vass::Errors::RateLimitError, with: :handle_rate_limit_error
    rescue_from VANotify::Error, with: :handle_vanotify_error

    private

    def handle_authentication_error(exception)
      log_safe_error('authentication_error', exception.class.name)
      render_error_response(
        title: 'Authentication Error',
        detail: 'Unable to authenticate request',
        code: 'authentication_error',
        status: :unauthorized
      )
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

    def handle_validation_error(exception)
      log_safe_error('validation_error', exception.class.name)
      render_error_response(
        title: 'Validation Error',
        detail: 'The request failed validation',
        code: 'validation_error',
        status: :unprocessable_entity
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
        title: 'Cache Error',
        detail: 'The caching service is temporarily unavailable',
        code: 'redis_error',
        status: :service_unavailable
      )
    end

    def handle_rate_limit_error(exception)
      log_safe_error('rate_limit_error', exception.class.name)
      render_error_response(
        title: 'Rate Limit Exceeded',
        detail: 'Too many requests. Please try again later',
        code: 'rate_limit_error',
        status: :too_many_requests
      )
    end

    def handle_vanotify_error(exception)
      log_safe_error('vanotify_error', exception.class.name)
      status = map_vanotify_status_to_http_status(exception.status_code)

      render_error_response(
        title: 'Notification Service Error',
        detail: 'Unable to send notification. Please try again later',
        code: 'notification_error',
        status:
      )
    end

    ##
    # Maps VANotify status codes to appropriate HTTP statuses.
    #
    # @param status_code [Integer] The VANotify error status code
    # @return [Symbol] HTTP status symbol
    #
    def map_vanotify_status_to_http_status(status_code)
      case status_code
      when 400
        :bad_request
      when 401, 403
        :unauthorized
      when 404
        :not_found
      when 429
        :too_many_requests
      when 500, 502, 503
        :bad_gateway
      else
        :service_unavailable
      end
    end

    # Logs error information without PHI
    # Only logs: error type, exception class, controller, action, status, timestamp
    def log_safe_error(error_type, exception_class)
      Rails.logger.error({
        service: 'vass',
        error_type:,
        exception_class:,
        controller: controller_name,
        action: action_name,
        timestamp: Time.current.iso8601
      }.to_json)
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
    # Preserves acronyms like UTC in uppercase.
    #
    # @param obj [Object] Object to transform (Hash, Array, or other)
    # @return [Object] Transformed object with camelized keys, or nil if input is nil
    #
    def camelize_keys(obj)
      return nil if obj.nil?

      case obj
      when Hash
        obj.transform_keys { |key| camelize_with_acronyms(key.to_s) }
           .transform_values { |value| camelize_keys(value) }
      when Array
        obj.map { |item| camelize_keys(item) }
      else
        obj
      end
    end

    ##
    # Camelizes a string key while preserving common acronyms in uppercase.
    #
    # @param key [String] The key to camelize
    # @return [String] Camelized key with acronyms preserved
    #
    def camelize_with_acronyms(key)
      camelized = key.camelize(:lower)
      # Preserve UTC acronym in uppercase for specific patterns
      # startUTC, endUTC (standalone fields from appointment data)
      camelized.gsub(/\A(start|end)Utc\z/, '\1UTC')
    end
  end
end
