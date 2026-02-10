# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'

module UnifiedHealthData
  module Adapters
    # Resolves facility names from station numbers using Lighthouse API with caching
    class FacilityNameResolver
      # Extracts facility name from a FHIR MedicationDispense resource
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [String, nil] Facility name or nil if not found
      def resolve_facility_name(dispense)
        return nil unless dispense

        station_number = extract_station_number(dispense)
        return nil unless station_number

        lookup(station_number)
      end

      # Extracts and validates station number from a FHIR MedicationDispense resource
      # Uses two-pass extraction and validates against known facility ranges
      #
      # @param dispense [Hash] FHIR MedicationDispense resource
      # @return [String, nil] Valid station number or nil if not found/invalid
      def extract_station_number(dispense)
        return nil unless dispense

        # Get .location.display from dispense
        location_display = dispense.dig('location', 'display')
        return nil unless location_display

        # First pass: Try the legacy 3-digit station number
        three_digit_station = location_display.match(/^(\d{3})/)&.[](1)
        return three_digit_station if three_digit_station && valid_station_number?(three_digit_station)

        # Second pass: Try the full facility identifier before the first hyphen (e.g., 648A4)
        facility_identifier = location_display.split('-').first
        # Valid format: 3 digits + up to 2 alpha (e.g., 648A, 648A4)
        valid_station_regex = /^\d{3}[A-Za-z0-9]{0,2}$/
        if facility_identifier.present? && facility_identifier != three_digit_station &&
           facility_identifier.match?(valid_station_regex) &&
           valid_station_number?(facility_identifier)
          return facility_identifier
        end

        # Log failure with raw location for debugging
        Rails.logger.warn(
          message: 'Unable to extract valid station number from Oracle Health location',
          location_display:,
          three_digit_candidate: three_digit_station,
          full_identifier_candidate: facility_identifier,
          service: 'unified_health_data'
        )

        # Track invalid station extractions
        StatsD.increment('unified_health_data.oracle_health.invalid_station_number',
                         tags: ["candidate:#{three_digit_station || 'none'}"])

        nil
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

        fetch_from_api(station_identifier)
      end

      private

      # Validates whether a station number is a recognized VistA facility
      # Uses Settings.mhv.facility_range and HealthFacility table for validation
      #
      # @param station_number [String] Station number to validate (e.g., '648' or '648A4')
      # @return [Boolean] True if station number is valid
      def valid_station_number?(station_number)
        return false if station_number.blank?

        # Extract numeric prefix for range validation (e.g., '648A4' -> 648)
        numeric_prefix = station_number.match(/^(\d{3})/)[1].to_i

        # Check against MHV facility range configuration (e.g., 358-758)
        facility_range = Settings.mhv&.facility_range
        if facility_range.present?
          min_station = facility_range['min']
          max_station = facility_range['max']

          # Station must be within configured range
          return false unless numeric_prefix >= min_station && numeric_prefix <= max_station
        end

        # Additional validation: Check HealthFacility table
        # This catches valid stations that might be outside the range but still legitimate
        HealthFacility.exists?(unique_id: station_number) ||
          HealthFacility.exists?(unique_id: numeric_prefix.to_s)
      rescue => e
        Rails.logger.error("Error validating station number #{station_number}: #{e.message}")
        false
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
