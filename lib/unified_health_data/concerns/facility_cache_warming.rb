# frozen_string_literal: true

module UnifiedHealthData
  module Concerns
    # Facility cache pre-warming for lab records.
    # Extracted from Service to keep class length manageable.
    module FacilityCacheWarming
      extend ActiveSupport::Concern

      private

      # Pre-warms facility cache to avoid N+1 API calls during record parsing.
      # Extracts unique station numbers and fetches each facility once.
      def prewarm_facility_cache(records)
        return if records.blank?

        all_station_numbers = records.map { |r| lab_or_test_adapter.extract_station_number_from_record(r) }
        station_numbers = all_station_numbers.compact.uniq

        log_facility_cache_metrics(records.size, all_station_numbers, station_numbers)

        facility_service = UnifiedHealthData::FacilityService.new
        station_numbers.each { |sn| facility_service.get_facility_with_cache(sn) }
      end

      def log_facility_cache_metrics(total_records, all_station_numbers, station_numbers)
        records_with_station = all_station_numbers.count(&:present?)

        Rails.logger.info(
          'UHD FacilityService: Pre-warming cache for facility timezones',
          {
            service: 'unified_health_data',
            total_records:,
            records_with_station_number: records_with_station,
            records_without_station_number: total_records - records_with_station,
            unique_station_numbers: station_numbers.size
          }
        )

        StatsD.gauge('api.uhd.facility.station_number_coverage',
                     (records_with_station.to_f / total_records * 100).round(1),
                     tags: ['source:labs'])
      end
    end
  end
end
