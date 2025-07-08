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
      user = User.find(user_uuid)
      
      unless user
        Rails.logger.error("UHD Labs Refresh Job: User not found for UUID: #{user_uuid}")
        return
      end

      # Calculate date range for the past month
      end_date = Date.current
      start_date = end_date - 1.month

      # Initialize the UHD service
      uhd_service = UnifiedHealthData::Service.new(user)
      
      # Fetch labs data for the past month
      labs_data = uhd_service.get_labs(
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      )

      # Log successful completion
      Rails.logger.info(
        "UHD Labs Refresh Job completed successfully",
        records_count: labs_data.size,
        start_date: start_date.strftime('%Y-%m-%d'),
        end_date: end_date.strftime('%Y-%m-%d')
      )

      # Return the count of records fetched
      labs_data.size
    rescue => e
      Rails.logger.error(
        "UHD Labs Refresh Job failed",
        error: e.message,
      )
      raise
    end
  end
end
