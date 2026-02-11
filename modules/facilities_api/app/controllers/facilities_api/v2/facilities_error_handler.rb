# frozen_string_literal: true

# Handles errors for Facilities API V2 controllers
module FacilitiesApi::V2::FacilitiesErrorHandler
  extend ActiveSupport::Concern

  included do
    around_action :handle_facilities_exceptions
  end

  private

  def handle_facilities_exceptions
    yield
  rescue => e
    handle_error("#{controller_name}_#{action_name}", e)
  end

  def handle_error(method, e)
    raise e
  rescue Common::Exceptions::InvalidFieldValue => e
    json_error(method, e, "Invalid field value: #{e.field}", '400', :bad_request)
  rescue Common::Exceptions::RecordNotFound, Faraday::ResourceNotFound, Net::HTTPNotFound => e
    json_error(method, e, 'Not Found', '404', :not_found)
  rescue Common::Exceptions::ServiceUnavailable => e
    json_error(method, e, 'Service Unavailable', '503', :service_unavailable)
  rescue Common::Exceptions::Timeout, Common::Exceptions::GatewayTimeout, Net::ReadTimeout, Faraday::TimeoutError => e
    json_error(method, e, 'Gateway Timeout', '504', :gateway_timeout)
  rescue Common::Exceptions::BackendServiceException, Common::Client::Errors::ClientError,
         Common::Client::Errors::ParsingError => e
    json_error(method, e, 'Bad Gateway', '502', :bad_gateway)
  rescue ActionController::ParameterMissing
    raise # Let global ExceptionHandling format this properly
  rescue => e
    Datadog::Tracing.active_span&.set_error(e)
    json_error("#{method}_unexpected", e, 'Internal server error', '500', :internal_server_error)
  end

  # Helper method to render JSON error responses
  # @param method [String] the name of the method where the error occurred
  # @param error [Exception] the exception object
  # @param title [String] the title of the error
  # @param code [String] the error code
  # @param status [Symbol] the HTTP status symbol
  def json_error(method, error, title, code, status)
    Rails.logger.error("Facilities API V2 #{method} error: #{error.class}")

    if Flipper.enabled?(:facilities_api_debug_logging)
      Rails.logger.debug { "Facilities API V2 #{method} full error: #{error.inspect}" }
    end

    real_status = Rack::Utils.status_code(status)
    render json: { errors: [{ title:, detail: error.message, code: }] }, status: real_status
  end
end
