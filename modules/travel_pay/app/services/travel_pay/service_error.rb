# frozen_string_literal: true

module TravelPay
  class ServiceError
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

    def self.raise_mapped_error(error)
      begin
        status_code = error.response_status
        symbolized_body = error.response_body.deep_symbolize_keys
        message = symbolized_body[:message]
      rescue
        if error.response_body.nil?
          Rails.logger.error(
            message: "raise_mapped_error received nil response_body. status: #{error.response_status}, returning 500. message: #{error.message.to_s}"
          )
          raise Common::Exceptions::ExternalServerInternalServerError.new(
            errors: [{ title: error.message.to_s, status: 500 }]
          )
        else
          raise Common::Exceptions::ServiceError
        end
      end

      # Log here
      raise Common::Exceptions::ServiceError unless ERROR_MAP.include?(status_code)

      raise ERROR_MAP[status_code].new(errors: [{ title: message, status: status_code }])
    end
  end
end
