# frozen_string_literal: true

require 'caseflow/service'

module AppealsApi
  class HealthChecker
    SERVICES = %w[caseflow].freeze

    def initialize
      @caseflow_healthy = nil
    end

    def services_are_healthy?
      caseflow_is_healthy?
    end

    def healthy_service?(service)
      case service
      when /caseflow/i
        caseflow_is_healthy?
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
  end
end
