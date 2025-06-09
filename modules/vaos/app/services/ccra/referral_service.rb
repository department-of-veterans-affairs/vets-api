# frozen_string_literal: true

module Ccra
  # Ccra::ReferralService provides methods for interacting with the CCRA referral endpoints.
  # It inherits from Ccra::BaseService for common REST functionality and configuration.
  class ReferralService < BaseService
    # Fetches the VAOS Referral List.
    #
    # @param icn [String] The ICN of the patient.
    # @param referral_status [String] The referral status of the patient.
    #
    # @return [Array<ReferralListEntry>] An array of ReferralListEntry objects representing the referral list.
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
    # If not, it makes a request to the CCRA API and caches the result.
    #
    # @param id [String] The ID of the referral.
    # @param icn [String] The ICN of the patient.
    #
    # @return [ReferralDetail] A ReferralDetail object representing the detailed referral information.
    def get_referral(id, icn)
      fetch_and_update_cached_referral(id, icn) || fetch_and_cache_referral(id, icn)
    end

    # Clears the referral data from the cache
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [Boolean] True if the cache operation was successful
    def clear_referral_cache(id, icn)
      referral_cache.clear_referral_data(id:, icn:)
    end

    # Gets the booking start time for a referral from the cache
    #
    # @param id [String] The referral ID
    # @param icn [String] The ICN of the patient
    # @return [Float, nil] The booking start time as a float timestamp, or nil if not found
    def fetch_booking_start_time(id, icn)
      cached_data = referral_cache.fetch_referral_data(id:, icn:)
      start_time = cached_data&.booking_start_time
      Rails.logger.warn('Referral booking start time not found.') unless start_time
      start_time
    end

    private

    # Retrieves a referral from the cache and updates its booking start time.
    # If the referral is found in cache, updates its booking start time to the current time
    # and saves it back to the cache.
    #
    # @param id [String] The ID of the referral to fetch
    # @param icn [String] The ICN of the patient
    # @return [ReferralDetail, nil] The cached referral with updated booking start time, or nil if not found
    def fetch_and_update_cached_referral(id, icn)
      cached_referral = referral_cache.fetch_referral_data(id:, icn:)
      return unless cached_referral

      cached_referral.booking_start_time = Time.current.to_f
      referral_cache.save_referral_data(id:, icn:, referral_data: cached_referral)
      cached_referral
    end

    # Fetches a referral from the CCRA API and caches it.
    # Sets the initial booking start time and stores the referral in the cache.
    #
    # @param id [String] The ID of the referral to fetch
    # @param icn [String] The ICN of the patient
    # @return [ReferralDetail] The newly fetched and cached referral
    def fetch_and_cache_referral(id, icn)
      with_monitoring do
        response = perform(:get, "/#{config.base_path}/#{icn}/referrals/#{id}", {}, request_headers)
        referral = ReferralDetail.new(response.body)
        cache_referral_data(referral, id, icn)
        referral
      end
    end

    # Caches the entire referral object for future use
    #
    # @param referral [ReferralDetail] The referral data object
    # @param id [String] The referral ID
    # @param icn [String] The patient's ICN
    # @return [Boolean] True if the cache operation was successful
    def cache_referral_data(referral, id, icn)
      referral.booking_start_time = Time.current.to_f

      referral_cache.save_referral_data(
        id:,
        icn:,
        referral_data: referral
      )
    end

    # Memoized CCRA Referral cache instance
    # @return [Ccra::RedisClient] the CCRA referral cache
    def referral_cache
      @referral_cache ||= Ccra::RedisClient.new
    end
  end
end
