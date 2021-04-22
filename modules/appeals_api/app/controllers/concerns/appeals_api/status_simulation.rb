# frozen_string_literal: true

module AppealsApi
  class StatusSimulator < SimpleDelegator
    attr_accessor :status
  end

  module StatusSimulation
    extend ActiveSupport::Concern

    included do
      def status_simulation_reqested?
        request.headers['Status-Simulation']
      end

      def status_simulation_allowed?
        allowed_envs = %w[development sandbox staging]
        Settings.modules_appeals_api.status_simulation_enabled && allowed_envs.include?(Settings.vsp_environment)
      end

      def status_simulation_for(appeal)
        wrapped_appeal = StatusSimulator.new(appeal)
        wrapped_appeal.status = request.headers['Status-Simulation']
        wrapped_appeal
      end
    end
  end
end
