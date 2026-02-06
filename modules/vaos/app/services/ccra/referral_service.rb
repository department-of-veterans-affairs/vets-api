# frozen_string_literal: true

require 'logging/helper/data_scrubber'

module Ccra
  # Ccra::ReferralService provides methods for interacting with the CCRA referral endpoints.
  # It inherits from Ccra::BaseService for common REST functionality and configuration.
  # This service handles both API interactions and caching of referral data.
  class ReferralService < BaseService
    include Logging::Helper::DataScrubber

    # Number of characters to log from PII fields for safety
    SAFE_LOG_LENGTH = 3

    # Fetches the VAOS Referral List.
    #
    # @param icn [String] The Internal Control Number (ICN) of the patient
    # @param referral_status [String] The status to filter referrals by (e.g., 'ACTIVE', 'CANCELLED')
    #
    # @return [Array<ReferralListEntry>] An array of ReferralListEntry objects containing the filtered referral list
    def get_vaos_referral_list(icn, referral_status)
      params = { status: referral_status }
      with_monitoring do
        response = perform(:get, "/#{config.base_path}/#{icn}/referrals", params, request_headers)
        ReferralListEntry.build_collection(response.body)
      end
    rescue => e
      log_referral_list_error(referral_status, e)
      raise e
    end

    # Retrieves detailed Referral information.
    # First checks if the referral data is available in the cache.
    # If not found in cache:
    # 1. Makes a monitored request to the CCRA API
    # 2. Caches the result for future use
    # 3. Updates the booking start time
    # Cache operations are performed outside monitoring to ensure accurate API performance metrics.
    #
    # @param id [String] The unique identifier of the referral
    # @param icn [String] The Internal Control Number (ICN) of the patient
    #
    # @return [ReferralDetail] A ReferralDetail object containing the referral's detailed information,
    #   either from cache or freshly fetched from the API
    def get_referral(id, icn)
      referral = referral_cache.fetch_referral_data(id:, icn:)

      unless referral
        with_monitoring do
          response = perform(:get, "/#{config.base_path}/#{icn}/referrals/#{id}", {}, request_headers)

          # Log both NPI fields from raw CCRA response
          log_ccra_npi_fields(response.body, id)

          referral = ReferralDetail.new(response.body)
        end
        cache_referral_data(referral, id, icn)
      end

      cache_booking_start_time(referral.referral_number)
      referral
    end

    # Removes the cached referral data for a specific referral and patient.
    # This is useful when the cached data needs to be refreshed or is no longer valid.
    #
    # @param id [String] The unique identifier of the referral to clear from cache
    # @param icn [String] The Internal Control Number (ICN) of the patient
    #
    # @return [Boolean] true if the cache was successfully cleared, false otherwise
    def clear_referral_cache(id, icn)
      referral_cache.clear_referral_data(id:, icn:)
    end

    # Retrieves the booking start time for a referral from the cache.
    # First fetches the referral data to get the referral number, then looks up the booking start time.
    # Logs a warning if the booking start time is not found.
    #
    # @param id [String] The unique identifier of the referral
    # @param icn [String] The Internal Control Number (ICN) of the patient
    #
    # @return [Float, nil] The Unix timestamp of when the booking started,
    #   or nil if either the referral or booking start time is not found in cache
    def get_booking_start_time(id, icn)
      cached_data = referral_cache.fetch_referral_data(id:, icn:)
      referral_number = cached_data&.referral_number
      return nil unless referral_number

      start_time = referral_cache.fetch_booking_start_time(referral_number:)
      Rails.logger.warn('Community Care Appointments: Referral booking start time not found.') unless start_time
      start_time
    end

    # Retrieves cached referral data
    #
    # @param id [String] The unique identifier of the referral
    # @param icn [String] The Internal Control Number (ICN) of the patient
    #
    # @return [ReferralDetail, nil] The cached referral object or nil if not found in cache
    # @raise [Redis::BaseError] if Redis connection fails
    def get_cached_referral_data(id, icn)
      referral_cache.fetch_referral_data(id:, icn:)
    end

    private

    # Logs an error when fetching the VAOS referral list fails.
    #
    # @param referral_status [String] The status filter that was used in the failed request
    # @param error [Exception] The exception that was raised
    #
    # @return [void]
    def log_referral_list_error(referral_status, error)
      return unless Flipper.enabled?(:va_online_scheduling_ccra_error_logging, user)

      Rails.logger.error('Community Care Appointments: Failed to fetch VAOS referral list', {
                           referral_status:,
                           service: 'ccra',
                           method: 'get_vaos_referral_list',
                           error_class: error.class.name,
                           error_message: scrub(error.message),
                           error_backtrace: error.backtrace&.first(5)
                         })
    end

    # Stores the provided referral data in the cache for future retrieval.
    #
    # @param referral [ReferralDetail] The referral object to cache
    # @param id [String] The unique identifier of the referral
    # @param icn [String] The Internal Control Number (ICN) of the patient
    #
    # @return [Boolean] true if the cache operation was successful
    def cache_referral_data(referral, id, icn)
      referral_cache.save_referral_data(
        id:,
        icn:,
        referral_data: referral
      )
    end

    # Returns a memoized instance of the CCRA Redis cache client.
    # Creates a new instance if one doesn't exist.
    #
    # @return [Ccra::RedisClient] The Redis cache client instance
    def referral_cache
      @referral_cache ||= Ccra::RedisClient.new
    end

    # Records the current timestamp as the booking start time for a referral.
    # Generates a Unix timestamp (seconds since epoch) using Time.current and stores it in the cache.
    # This timestamp is used to track when a booking process began.
    #
    # @param referral_number [String] The referral number to associate with the start time
    # @return [Boolean] true if the timestamp was successfully cached
    def cache_booking_start_time(referral_number)
      referral_cache.save_booking_start_time(
        referral_number:,
        booking_start_time: Time.current.to_f
      )
    end

    # Logs all NPI fields from CCRA response (root-level and nested)
    # Safely logs field names and only last 3 characters of NPI values
    #
    # @param response_body [Hash] The raw CCRA API response body
    # @param referral_id [String] The referral ID for context
    # @return [void]
    def log_ccra_npi_fields(response_body, referral_id)
      log_data = { referral_id_last3: referral_id.to_s.last(SAFE_LOG_LENGTH) }

      log_root_npi_fields(response_body, log_data)
      log_nested_npi_fields(response_body, log_data)
      log_additional_npi_fields(response_body, log_data)

      Rails.logger.info("#{CC_APPOINTMENTS}: CCRA referral NPI fields", log_data.compact)
    end

    def log_root_npi_fields(response_body, log_data)
      root_npi_fields = {
        primary_care_provider_npi: response_body[:primary_care_provider_npi],
        referring_provider_npi: response_body[:referring_provider_npi],
        treating_provider_npi: response_body[:treating_provider_npi]
      }

      add_npi_field_to_log(root_npi_fields, log_data)
    end

    def log_nested_npi_fields(response_body, log_data)
      nested_npi_fields = {
        referring_provider_info_npi: response_body.dig(:referring_provider_info, :provider_npi),
        treating_provider_info_npi: response_body.dig(:treating_provider_info, :provider_npi)
      }

      add_npi_field_to_log(nested_npi_fields, log_data)
    end

    def log_additional_npi_fields(response_body, log_data)
      known_paths = ['primary_care_provider_npi', 'referring_provider_npi', 'treating_provider_npi',
                     'referring_provider_info.provider_npi', 'treating_provider_info.provider_npi']
      additional_npi_fields = find_npi_fields_recursive(response_body, '', known_paths)
      return if additional_npi_fields.empty?

      log_data[:additional_npi_fields] = additional_npi_fields.map do |field_path, value|
        { field: field_path, present: value.present?, last3: value.present? ? value.to_s.last(SAFE_LOG_LENGTH) : nil }
      end
    end

    def add_npi_field_to_log(npi_fields, log_data)
      npi_fields.each do |field_name, value|
        log_data[:"#{field_name}_present"] = value.present?
        log_data[:"#{field_name}_last3"] = value.present? ? value.to_s.last(SAFE_LOG_LENGTH) : nil
      end
    end

    # Recursively finds all fields containing "npi" in their name
    #
    # @param obj [Hash, Array, Object] The object to search
    # @param path [String] The current path in the object tree
    # @param known_paths [Array<String>] Paths we've already logged to avoid duplicates
    # @return [Array<Array>] Array of [field_path, value] pairs
    def find_npi_fields_recursive(obj, path, known_paths)
      results = []

      case obj
      when Hash
        obj.each do |key, value|
          current_path = path.empty? ? key.to_s : "#{path}.#{key}"
          results << [current_path, value] if key.to_s.downcase.include?('npi') && known_paths.exclude?(current_path)
          results.concat(find_npi_fields_recursive(value, current_path, known_paths))
        end
      when Array
        obj.each_with_index do |item, index|
          current_path = "#{path}[#{index}]"
          results.concat(find_npi_fields_recursive(item, current_path, known_paths))
        end
      end

      results
    end
  end
end
