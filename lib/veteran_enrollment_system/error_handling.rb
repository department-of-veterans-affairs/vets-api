module VeteranEnrollmentSystem
  module ErrorHandling
    ERROR_MAP = {
      400 => Common::Exceptions::BadRequest,
      403 => Common::Exceptions::Forbidden,
      404 => Common::Exceptions::ResourceNotFound,
      500 => Common::Exceptions::ExternalServerInternalServerError,
      502 => Common::Exceptions::BadGateway,
      504 => Common::Exceptions::GatewayTimeout
    }.freeze

    def raise_error(response)
      message = response.body['messages']&.pluck('description')&.join(', ') || response.body
      # Just in case the status is not in the ERROR_MAP, raise a BackendServiceException
      raise ERROR_MAP[response.status]&.new(detail: message) ||
            Common::Exceptions::BackendServiceException.new(nil, detail: message)
    end
  end
end
