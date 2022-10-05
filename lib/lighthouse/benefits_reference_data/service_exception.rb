# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'

module BenefitsReferenceData
  # Custom exception that maps Decision Review errors to error details defined in config/locales/exceptions.en.yml
  #
  class ServiceException
    include SentryLogging

    def initialize(e)
      raise e unless e.respond_to?(:status)

      case e.status.to_i
      when 404
        raise Common::Exceptions::ResourceNotFound
      when 403
        raise Common::Exceptions::Forbidden
      else
        raise e
      end
    end
  end
end
