# frozen_string_literal: true

module Ccra
  # Ccra::ReferralService provides methods for interacting with the CCRA referral endpoints.
  # It inherits from Ccra::BaseService for common REST functionality and configuration.
  # This service handles both API interactions and caching of referral data.
  class ReferralService < BaseService
    # Fetches the VAOS Referral List.
    #
    # @param icn [String] The Internal Control Number (ICN) of the patient
    # @param referral_status [String] The status to filter referrals by (e.g., 'ACTIVE', 'CANCELLED')
    #
    # @return [Array<ReferralListEntry>] An array of ReferralListEntry objects containing the filtered referral list
    def get_vaos_referral_list(icn, referral_status)
      params = { status: referral_status }
      with_monitoring do
        response = perform(
          :get,
          "/#{config.base_path}/#{icn}/referrals",
          params,
          request_headers
        )

        ReferralListEntry.build_collection(response.body)
      end
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
  end
end
