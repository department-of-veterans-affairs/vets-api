# frozen_string_literal: true

# Handles errors for Facilities API V2 controllers
module FacilitiesApi::V2::FacilitiesError
  def handle_error(method, e)
    raise e
  rescue Common::Exceptions::RecordNotFound, Faraday::ResourceNotFound, Net::HTTPNotFound => e
    json_error(method, e, 'Not Found', '404', :not_found)
  rescue Common::Exceptions::ServiceUnavailable => e
    json_error(method, e, 'Service Unavailable', '503', :service_unavailable)
  rescue Common::Exceptions::Timeout, Net::ReadTimeout, Faraday::TimeoutError => e
    json_error(method, e, 'Gateway Timeout', '504', :gateway_timeout)
  rescue Common::Exceptions::BackendServiceException => e
    json_error(method, e, 'Bad Gateway', '502', :bad_gateway)
  end

  def json_error(method, error, title, code, status)
    Rails.logger.error("Facilities API V2 #{method} error: #{error.class}")

    if Flipper.enabled?(:facilities_api_debug_logging)
      Rails.logger.debug { "Facilities API V2 #{method} full error: #{error.inspect}" }
    end

    real_status = Rack::Utils.status_code(status)
    render json: { errors: [{ title:, detail: error.message, code: }] }, status: real_status
  end
end
