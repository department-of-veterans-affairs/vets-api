# frozen_string_literal: true

require 'sidekiq'

module Crm
  class FacilitiesDataJob
    include Sidekiq::Job

    # Schedule to run every 24 hours. Adjust as needed.
    sidekiq_options retry: false, unique_for: 24.hours

    def perform
      Crm::CacheData.new.fetch_and_cache_data(endpoint: 'Facilities', cache_key: 'Facilities', payload: {})
    rescue => e
      log_error('optionset', e)
    end

    private

    def log_error(action, exception)
      LogService.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end
  end
end
