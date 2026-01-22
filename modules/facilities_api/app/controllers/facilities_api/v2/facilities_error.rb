# frozen_string_literal: true

# Handles errors for Facilities API V2 controllers
module FacilitiesError
  def handle_error(error, method)
    return unless error

    status = error.respond_to?(:response) ? error.response[:status] : nil

    Rails.logger.error("Facilities API V2 #{method} error: #{error.message}")
    if error.is_a?(Common::Exceptions::RecordNotFound) || error.is_a?(Faraday::ResourceNotFound) ||
       error.is_a?(Net::HTTPNotFound) || status == 404
      json_error(error, 'Not Found', '404', :not_found)
    elsif error.is_a?(Common::Exceptions::BackendServiceException) && status == 502
      json_error(error, 'Bad Gateway', '502', :bad_gateway)
    elsif error.is_a?(Common::Exceptions::BackendServiceException) && status == 503
      json_error(error, 'Service Unavailable', '503', :service_unavailable)
    elsif error.is_a?(Common::Exceptions::Timeout) || error.is_a?(Net::ReadTimeout) ||
          error.is_a?(Faraday::TimeoutError) || status == 504
      json_error(error, 'Gateway Timeout', '504', :gateway_timeout)
    elsif error.is_a?(Common::Exceptions::BackendServiceException)
      json_error(error, 'Backend Service Error', error.response[:message].to_s, 500)
    else
      # Some other error we handle by giving something like a 400 to the user
      # i.e. invalid parameters, etc.
      raise error
    end
  end

  def json_error(error, title, code, status = :internal_server_error)
    render json: { errors: [{ title:, detail: error.message, code: }] }, status:
  end
end
