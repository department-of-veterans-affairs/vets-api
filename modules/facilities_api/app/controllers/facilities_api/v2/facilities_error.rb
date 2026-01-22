# frozen_string_literal: true

# Handles errors for Facilities API V2 controllers
module FacilitiesApi::V2::FacilitiesError
  def handle_error(error, method)
    nil unless error
  rescue Common::Exceptions::RecordNotFound, Faraday::ResourceNotFound, Net::HTTPNotFound
    json_error(method, error, 'Not Found', '404', :not_found)
  rescue Common::Exceptions::BackendServiceException
    json_error(method, error, 'Bad Gateway', '502', :bad_gateway)
  rescue Common::Exceptions::ServiceUnavailable
    json_error(method, error, 'Service Unavailable', '503', :service_unavailable)
  rescue Common::Exceptions::Timeout, Net::ReadTimeout, Faraday::TimeoutError
    json_error(method, error, 'Gateway Timeout', '504', :gateway_timeout)
  end

  def json_error(method, error, title, code, status = :internal_server_error)
    Rails.logger.error("Facilities API V2 #{method} error: #{error.message}")
    real_status = Rack::Utils.status_code(status)
    render json: { errors: [{ title:, detail: error.message, code: }] }, status: real_status
  end
end
