# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions'
require_relative 'facility_configuration'

module UnifiedHealthData
  # Service for fetching VA facility information, specifically timezone data.
  # This is a standalone service for Medical Records, independent of VAOS.
  #
  # Uses the VA Mobile Facilities API: /facilities/v2/facilities/:id
  #
  # Example usage:
  #   service = UnifiedHealthData::FacilityService.new
  #   timezone = service.get_facility_timezone('668')
  #   # => 'America/Los_Angeles'
  #
  class FacilityService < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.uhd.facility'
    CACHE_TTL = 12.hours

    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::FacilityConfiguration

    # Gets the IANA timezone ID for a facility, with caching.
    #
    # @param station_number [String] The station number (e.g., '668')
    # @return [String, nil] IANA timezone ID (e.g., 'America/Los_Angeles') or nil if not found
    def get_facility_timezone(station_number)
      return nil if station_number.blank?

      facility = get_facility_with_cache(station_number)
      return nil if facility.nil?

      facility.dig(:timezone, :time_zone_id) || facility.dig('timezone', 'timeZoneId')
    end

    # Gets facility information with caching.
    #
    # @param facility_id [String] The facility/station ID
    # @return [Hash, nil] Facility information or nil on error
    def get_facility_with_cache(facility_id)
      Rails.cache.fetch(cache_key(facility_id), expires_in: CACHE_TTL) do
        get_facility(facility_id)
      end
    end

    # Gets facility information from the API.
    #
    # @param facility_id [String] The facility/station ID
    # @return [Hash, nil] Facility information or nil on error
    def get_facility(facility_id)
      with_monitoring do
        response = perform(:get, facilities_url(facility_id), {}, headers)
        parse_response(response)
      end
    rescue Common::Exceptions::BackendServiceException, StandardError => e
      log_facility_error(facility_id, e)
      nil
    end

    private

    def facilities_url(facility_id)
      "/facilities/v2/facilities/#{facility_id}"
    end

    def headers
      { 'Content-Type' => 'application/json' }
    end

    def cache_key(facility_id)
      "uhd_facility_#{facility_id}"
    end

    def parse_response(response)
      return nil if response.body.blank?

      if response.body.is_a?(Hash)
        response.body.with_indifferent_access
      elsif response.body.is_a?(String)
        JSON.parse(response.body).with_indifferent_access
      else
        response.body
      end
    end

    def log_facility_error(facility_id, error)
      Rails.logger.warn(
        "UHD FacilityService error fetching facility #{facility_id}: #{error.message}",
        {
          service: 'unified_health_data',
          facility_id:,
          error_class: error.class.name
        }
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.error", tags: ["facility_id:#{facility_id}"])
    end
  end
end
