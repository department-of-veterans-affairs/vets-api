# frozen_string_literal: true

require 'unified_health_data/service'

##
# Background job to load lab data from the Unified Health Data service
#
module UnifiedHealthData
  class LabsRefreshJob
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(user_uuid)
      user = find_user(user_uuid)
      return unless user

      labs_data = fetch_labs_data(user)
      log_success(labs_data)
      labs_data.size
    rescue => e
      log_error(e)
      raise
    end

    private

    def find_user(user_uuid)
      user = User.find(user_uuid)
      return user if user

      Rails.logger.error("UHD Labs Refresh Job: User not found for UUID: #{user_uuid}")
      nil
    end

    def fetch_labs_data(user)
      end_date = Date.current
      start_date = end_date - 1.month

      uhd_service = UnifiedHealthData::Service.new(user)
      uhd_service.get_labs(
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      )
    end

    def log_success(labs_data)
      end_date = Date.current
      start_date = end_date - 1.month

      Rails.logger.info(
        'UHD Labs Refresh Job completed successfully',
        records_count: labs_data.size,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      )
    end

    def log_error(error)
      Rails.logger.error(
        'UHD Labs Refresh Job failed',
        error: error.message
      )
    end
  end
end
