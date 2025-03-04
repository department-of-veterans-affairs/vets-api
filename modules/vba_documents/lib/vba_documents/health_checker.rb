# frozen_string_literal: true

require 'central_mail/service'

module VBADocuments
  class HealthChecker
    SERVICES = %w[central_mail].freeze

    def initialize
      @central_mail_healthy = nil
    end

    def services_are_healthy?
      central_mail_is_healthy?
    end

    def healthy_service?(service)
      case service
      when /central_mail/i
        central_mail_is_healthy?
      else
        raise "VBADocuments::HealthChecker doesn't recognize #{service}"
      end
    end

    private

    def central_mail_is_healthy?
      return @central_mail_healthy unless @central_mail_healthy.nil?

      @central_mail_healthy = CentralMail::Service.service_is_up?
    end
  end
end
