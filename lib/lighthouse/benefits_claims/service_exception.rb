# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

module BenefitsClaims
  # Custom exception that maps Benefits Claims errors to error details defined in config/locales/exceptions.en.yml
  #
  class ServiceException
    include SentryLogging

    ERROR_MAP = {
      504 => Common::Exceptions::GatewayTimeout,
      503 => Common::Exceptions::ServiceUnavailable,
      502 => Common::Exceptions::BadGateway,
      500 => Common::Exceptions::ExternalServerInternalServerError,
      429 => Common::Exceptions::TooManyRequests,
      413 => Common::Exceptions::PayloadTooLarge,
      404 => Common::Exceptions::ResourceNotFound,
      403 => Common::Exceptions::Forbidden,
      401 => Common::Exceptions::Unauthorized,
      400 => Common::Exceptions::BadRequest
    }.freeze

    def initialize(e)
      raise e unless e.key?(:status)

      status = e[:status].to_i
      raise_exception(status)
    end

    def raise_exception(status)
      raise e unless ERROR_MAP.include?(status)

      raise ERROR_MAP[status]
    end
  end
end
