# frozen_string_literal: true

require 'caseflow/service'

module AppealsApi
  class HealthChecker
    def self.services_are_healthy?
      response = Caseflow::Service.new.healthcheck
      response.body['healthy'] == true
    end
  end
end
