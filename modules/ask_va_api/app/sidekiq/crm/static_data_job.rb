# frozen_string_literal: true

require 'sidekiq'
module Crm
  class StaticDataJob
    include Sidekiq::Job

    # Schedule to run every 24 hours. Adjust as needed.
    sidekiq_options retry: false, unique_for: 24.hours

    def perform
      ::Crm::StaticData.new.fetch_api_data
    rescue => e
      # Handle errors appropriately
      logger.error "Failed to update static data: #{e.message}"
    end
  end
end
