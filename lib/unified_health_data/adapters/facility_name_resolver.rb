# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'

module UnifiedHealthData
  module Adapters
    # Resolves facility names from station numbers using Lighthouse API with caching
    class FacilityNameResolver
      # Valid VA station numbers start with exactly 3 digits followed by a non-digit
      # character or end of string (e.g., '648', '648A4', '528GQ01', '648-RX-MAIN').
      # Non-matching identifiers (e.g., DoD 4+ digit codes, zz/x prefixes) are excluded.
      VA_STATION_PATTERN = /^\d{3}(?!\d)/

      # Extracts facility name from a FHIR MedicationDispense resource
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [String, nil] Facility name or nil if not found
      def resolve_facility_name(dispense)
        return nil unless dispense

        # Get .location.display from dispense
        location_display = dispense.dig('location', 'display')
        return nil unless location_display

        unless location_display.match?(VA_STATION_PATTERN)
          Rails.logger.info("Skipping non-VA station identifier: #{location_display}")
          return nil
        end

        three_digit_station = location_display[0, 3]

        # Try extended identifier first — more specific (e.g., 648A4 rather than just 648)
        facility_name = resolve_extended_station(location_display, three_digit_station)
        return facility_name if facility_name

        # Fall back to 3-digit station number
        lookup(three_digit_station)
      end

      # Looks up facility name by station identifier with caching
      #
      # @param station_identifier [String] Station number or identifier (e.g., '648' or '648A4')
      # @return [String, nil] Facility name or nil if not found
      def lookup(station_identifier)
        return nil if station_identifier.blank?

        cache_key = "uhd:facility_names:#{station_identifier}"
        cached_name = Rails.cache.read(cache_key)
        return cached_name if Rails.cache.exist?(cache_key)

        db_facility = HealthFacility.find_by(station_number: station_identifier)
        if db_facility
          Rails.cache.write(cache_key, db_facility.name, expires_in: 4.hours)
          return db_facility.name
        end

        fetch_from_api(station_identifier)
      end

      private

      # Attempts lookup using the extended facility identifier (e.g., 648A4 from '648A4-RX-MAIN')
      def resolve_extended_station(location_display, three_digit_station)
        facility_identifier = location_display.split('-').first
        valid_station_regex = /^\d{3}[A-Za-z0-9]+$/

        if facility_identifier.present? && facility_identifier != three_digit_station &&
           facility_identifier.match?(valid_station_regex)
          return lookup(facility_identifier)
        end

        nil
      end

      # Fetches facility name from Lighthouse API
      #
      # @param station_number [String] Station number or identifier
      # @return [String, nil] Facility name or nil if not found
      def fetch_from_api(station_number)
        facility_id = "vha_#{station_number}"
        cache_key = "uhd:facility_names:#{station_number}"

        begin
          facilities_client = Lighthouse::Facilities::V1::Client.new
          facilities = facilities_client.get_facilities(facilityIds: facility_id)

          facility_name = if facilities&.any?
                            facilities.first.name
                          else
                            Rails.logger.warn(
                              "No facility found for station number #{station_number} in Lighthouse API"
                            )
                            nil
                          end

          # Cache the result (including nil) to avoid repeated API calls
          # Keep TTL aligned with FacilityNameCacheJob refresh cadence (4 hours)
          Rails.cache.write(cache_key, facility_name, expires_in: 4.hours)

          facility_name
        rescue => e
          Rails.logger.error("Failed to fetch facility name from API for station #{station_number}: #{e.message}")
          StatsD.increment('unified_health_data.facility_name_fallback.api_error')
          nil
        end
      end
    end
  end
end
