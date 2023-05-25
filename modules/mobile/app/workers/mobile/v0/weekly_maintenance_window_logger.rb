# frozen_string_literal: true

require 'sidekiq'
require 'date'

module Mobile
  module V0
    class WeeklyMaintenanceWindowLogger
      include Sidekiq::Worker

      sidekiq_options retry: 3, unique_for: 1.week

      def perform
        upstream_maintenance_windows = ::MaintenanceWindow.where('created_at >= ?', 1.week.ago.beginning_of_day)
        parsed_windows = upstream_maintenance_windows.map(&:attributes)
        Rails.logger.info('Mobile - Maintenance Windows', parsed_windows) if parsed_windows.present?
      end
    end
  end
end
