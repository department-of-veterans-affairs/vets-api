# frozen_string_literal: true

require 'central_mail/service'

module VaForms
  class HealthChecker
    module Constants
      HEALTH_DESCRIPTION = 'VA Forms API Health Check'
      HEALTH_DESCRIPTION_UPSTREAM = 'VA Forms API Upstream Health Check'
      CMS_SERVICE = 'Content Management System'
    end
    include Constants

    SERVICES = [CMS_SERVICE].freeze

    def initialize
      @cms_healthy = nil
    end

    def services_are_healthy?
      cms_is_healthy?
    end

    def healthy_service?(service)
      case service.upcase

      when CMS_SERVICE.upcase
        cms_is_healthy?
      else
        raise "VaForms::HealthChecker doesn't recognize #{service}"
      end
    end

    private

    def cms_is_healthy?
      return @cms_healthy unless @cms_healthy.nil?

      @cms_healthy = VaForms::Form.count.positive?
    end
  end
end
