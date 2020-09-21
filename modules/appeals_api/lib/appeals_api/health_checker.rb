# frozen_string_literal: true

require 'caseflow/service'

module AppealsApi
  class HealthChecker
    def self.services_are_healthy?
      caseflow_is_healthy?
    end

    def self.caseflow_is_healthy?
      response = Caseflow::Service.new.healthcheck
      response.body['healthy'] == true
    end
  end
end
