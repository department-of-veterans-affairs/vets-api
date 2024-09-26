# frozen_string_literal: true

require 'sidekiq'

module Crm
  class OptionsetDataJob
    include Sidekiq::Job

    # Schedule to run every 24 hours. Adjust as needed.
    sidekiq_options retry: false, unique_for: 24.hours

    def perform
      options.each { |option| safely_retrieve_and_cache_optionset_data(option) }
    end

    private

    def options
      %w[
        inquiryabout inquirysource inquirytype levelofauthentication
        suffix veteranrelationship dependentrelationship responsetype
      ]
    end

    # Safely retrieves data for a given option, continues on failure
    def safely_retrieve_and_cache_optionset_data(option)
      Crm::CacheData.new.fetch_and_cache_data(
        endpoint: 'optionset',
        cache_key: option,
        payload: { name: "iris_#{option}" }
      )
    rescue => e
      log_error(option, e)
    end

    def log_error(action, exception)
      LogService.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end
  end
end
