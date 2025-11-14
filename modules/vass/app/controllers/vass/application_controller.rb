# frozen_string_literal: true

module Vass
  # Base controller for all VASS API endpoints
  # Inherits from ::ApplicationController which provides ExceptionHandling, Headers, and other concerns
  #
  # PHI SAFETY: All error handlers use static messages only. Never log or render exception.message
  # as it may contain patient health information. Only log safe context: error type, class, action.
  class ApplicationController < ::ApplicationController
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

    private

    def handle_authentication_error(exception)
      log_safe_error('authentication_error', exception.class.name)
      render_error_response(
        title: 'Authentication Error',
        detail: 'Unable to authenticate request',
        status: :unauthorized
      )
    end

    def handle_not_found_error(exception)
      log_safe_error('not_found', exception.class.name)
      render_error_response(
        title: 'Not Found',
        detail: 'The requested resource was not found',
        status: :not_found
      )
    end

    def handle_validation_error(exception)
      log_safe_error('validation_error', exception.class.name)
      render_error_response(
        title: 'Validation Error',
        detail: 'The request failed validation',
        status: :unprocessable_entity
      )
    end

    def handle_service_error(exception)
      log_safe_error('service_error', exception.class.name)
      render_error_response(
        title: 'Service Error',
        detail: 'The service is temporarily unavailable',
        status: :service_unavailable
      )
    end

    def handle_vass_api_error(exception)
      log_safe_error('vass_api_error', exception.class.name)
      render_error_response(
        title: 'VASS API Error',
        detail: 'Unable to process request with appointment service',
        status: :bad_gateway
      )
    end

    def handle_redis_error(exception)
      log_safe_error('redis_error', exception.class.name)
      render_error_response(
        title: 'Cache Error',
        detail: 'The caching service is temporarily unavailable',
        status: :service_unavailable
      )
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
    def render_error_response(title:, detail:, status:)
      status_code = Rack::Utils.status_code(status)
      render json: {
        errors: [{
          title:,
          detail:,
          code: status_code.to_s
        }]
      }, status:
    end
  end
end
