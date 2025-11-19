# frozen_string_literal: true

require 'common/exceptions/backend_service_exception'
require 'vets/shared_logging'

module BenefitsReferenceData
  # Custom exception that maps Decision Review errors to error details defined in config/locales/exceptions.en.yml
  #
  class ServiceException
    include Vets::SharedLogging

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
