# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

module VeteranVerification
  # Custom exception that maps Benefits Claims errors to error details defined in config/locales/exceptions.en.yml
  #
  class ServiceException
    include SentryLogging

    def initialize(e)
      raise e unless e.key?(:status)

      case e[:status].to_i
      when 429
        raise Common::Exceptions::TooManyRequests
      when 404
        raise Common::Exceptions::ResourceNotFound
      when 403
        raise Common::Exceptions::Forbidden
      when 401
        raise Common::Exceptions::Unauthorized
      else
        raise e
      end
    end
  end
end
