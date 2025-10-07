# frozen_string_literal: true

module UnifiedHealthData
  # FacilityNameCacheJob
  #
  # This Sidekiq job fetches VHA facilities from the Lighthouse Facilities API
  # and caches a mapping of station_number -> facility_name in Rails cache.
  # The cache is set to expire after 4 hours to ensure fresh data with hourly refreshes.
  #
  # Why:
  # - Prescription processing needs facility names for station numbers from Oracle Health
  # - Making individual API calls per prescription is inefficient and can hit rate limits
  # - HealthFacility table excludes some facilities that VHA includes
  # - Rails cache provides fast lookups with automatic expiration
  #
  # How:
  # - Fetches all VHA facilities from Lighthouse API
  # - Extracts station numbers from facility IDs (removes 'vha_' prefix)
  # - Stores station_number -> facility_name mapping in Rails cache
  # - Sets 4-hour TTL with hourly refresh for reliability
  #
  class FacilityNameCacheJob
    include Sidekiq::Job

    CACHE_KEY_PREFIX = 'uhd:facility_names'
    BATCH_SIZE = 1000

    # retry for ~30 minutes max since job runs every hour
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 3

    sidekiq_retries_exhausted do |msg|
      Rails.logger.error("[UnifiedHealthData] - #{msg['class']} failed with no retries left: #{msg['error_message']}")
      StatsD.increment('unified_health_data.facility_name_cache_job.failed_no_retries')
    end

    def perform
      Rails.logger.info('[UnifiedHealthData] - Starting facility name cache refresh')

      facility_map = fetch_vha_facilities
      cache_facility_names(facility_map)

      Rails.logger.info("[UnifiedHealthData] - Cached #{facility_map.size} VHA facility names")
      StatsD.increment('unified_health_data.facility_name_cache_job.complete')
      StatsD.gauge('unified_health_data.facility_name_cache_job.facilities_cached', facility_map.size)
    rescue => e
      Rails.logger.error("[UnifiedHealthData] - Error in #{self.class.name}: #{e.message}")
      StatsD.increment('unified_health_data.facility_name_cache_job.error')
      raise "Failed to cache facility names: #{e.message}"
    end

    private

    def fetch_vha_facilities
      facilities_client = Lighthouse::Facilities::V1::Client.new
      all_facilities = []
      page = 1

      Rails.logger.info('[UnifiedHealthData] - Fetching VHA facilities from Lighthouse API')

      loop do
        facilities = facilities_client.get_paginated_facilities(
          type: 'health',
          per_page: BATCH_SIZE,
          page:
        )

        # Filter to VHA facilities and extract station numbers
        vha_facilities = facilities.facilities.filter_map do |facility|
          next unless facility.id.start_with?('vha_')

          station_number = facility.id.sub(/^vha_/, '')
          { station_number:, name: facility.name }
        end

        all_facilities.concat(vha_facilities)
        break if facilities.facilities.size < BATCH_SIZE

        page += 1
      end

      # Convert to hash for easy lookup
      all_facilities.to_h { |facility| [facility[:station_number], facility[:name]] }
    end

    def cache_facility_names(facility_map)
      return if facility_map.empty?

      Rails.logger.info('[UnifiedHealthData] - Caching facility names for 4 hours')

      # Cache current facility names using Rails cache
      facility_map.each do |station_number, facility_name|
        cache_key = "#{CACHE_KEY_PREFIX}:#{station_number}"
        Rails.cache.write(cache_key, facility_name, expires_in: 4.hours)
      end

      Rails.logger.info("[UnifiedHealthData] - Cache operation complete: #{facility_map.size} facilities cached")
    end
  end
end
