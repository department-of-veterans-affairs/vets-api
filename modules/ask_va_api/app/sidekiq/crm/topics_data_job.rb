# frozen_string_literal: true

require 'sidekiq'
module Crm
  class TopicsDataJob
    include Sidekiq::Job

    # Schedule to run every 24 hours. Adjust as needed.
    sidekiq_options retry: false, unique_for: 24.hours

    def perform
      ::Crm::CacheData.new.fetch_api_data(endpoint: 'topics', cache_key: 'categories_topics_subtopics')
    rescue => e
      # Handle errors appropriately
      logger.error "Failed to update Topics data: #{e.message}"
    end
  end
end
