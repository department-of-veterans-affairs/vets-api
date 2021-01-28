# frozen_string_literal: true

require 'caseflow/service'

module AppealsApi
  class HealthChecker
    APPEALS_SERVICES = %w[caseflow].freeze
    DECISION_REVIEWS_SERVICES = %w[caseflow central_mail].freeze

    def initialize
      @caseflow_healthy = nil
      @central_mail_healthy = nil
    end

    def appeals_services_are_healthy?
      caseflow_is_healthy?
    end

    def decision_reviews_services_are_healthy?
      caseflow_is_healthy? && central_mail_is_healthy?
    end

    def healthy_service?(service)
      case service
      when /caseflow/i
        caseflow_is_healthy?
      when /central_mail/i
        central_mail_is_healthy?
      else
        raise "AppealsApi::HealthChecker doesn't recognize #{service}"
      end
    end

    private

    def caseflow_is_healthy?
      return @caseflow_healthy unless @caseflow_healthy.nil?

      response = Caseflow::Service.new.healthcheck
      @caseflow_healthy = response.body['healthy'] == true
    end

    def central_mail_is_healthy?
      return @central_mail_healthy unless @central_mail_healthy.nil?

      @central_mail_healthy = !CentralMail::Service.current_breaker_outage?
    end
  end
end
