# frozen_string_literal: true

module AppealsApi
  class StatusSimulator < SimpleDelegator
    attr_reader :status

    def status=(status)
      @status = if __getobj__.class::STATUSES.include?(status)
                  status
                else
                  __getobj__.status
                end
    end
  end

  module StatusSimulation
    extend ActiveSupport::Concern

    included do
      def status_requested_and_allowed?
        status_simulation_requested? && status_simulation_allowed?
      end

      def status_simulation_requested?
        request.headers['Status-Simulation']
      end

      def status_simulation_allowed?
        allowed_envs = %w[development sandbox staging]
        Settings.modules_appeals_api.status_simulation_enabled && allowed_envs.include?(Settings.vsp_environment)
      end

      def with_status_simulation(appeal)
        wrapped_appeal = StatusSimulator.new(appeal)
        wrapped_appeal.status = request.headers['Status-Simulation']
        wrapped_appeal
      end
    end
  end
end
