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

    # Raises mapped error, logs, and increments StatsD for error cases.
    # Optionally accepts a statsd_key_prefix and operation name for metrics/logging.
    def raise_error(response, statsd_key_prefix: nil, operation: nil)
      message = response.body['messages']&.pluck('description')&.join(', ') || response.body

      if statsd_key_prefix && operation
        StatsD.increment("#{statsd_key_prefix}.#{operation}.failed")
        Rails.logger.error(
          "#{operation} failed: #{message}"
        )
      end

      # Just in case the status is not in the ERROR_MAP, raise a BackendServiceException
      raise ERROR_MAP[response.status]&.new(detail: message) ||
            Common::Exceptions::BackendServiceException.new(nil, detail: message)
    end
  end
end
