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

        # Log the response body for debugging purposes, will remove upon completion of staging testing
        body_preview = response.body.is_a?(String) ? response.body : response.body.inspect
        Rails.logger.info("CCRA Referral List - Req headers: #{request_headers}")
        Rails.logger.info("CCRA Referral List - Params: #{params}")
        Rails.logger.info("CCRA Referral List - Content-Type: #{response.response_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

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
      # Check if referral data is in cache
      cached_referral = referral_cache.fetch_referral_data(id:, icn:)
      return cached_referral if cached_referral

      # If not in cache, fetch from API and cache the result
      params = {}
      with_monitoring do
        response = perform(
          :get,
          "/#{config.base_path}/#{icn}/referrals/#{id}",
          params,
          request_headers
        )

        # Log the response body for debugging purposes, will remove upon completion of staging testing
        body_preview = response.body.is_a?(String) ? response.body[0..100] : response.body.inspect[0..100]
        Rails.logger.info("CCRA Referral Detail - Req headers: #{request_headers}")
        Rails.logger.info("CCRA Referral Detail - Params: #{params}")
        Rails.logger.info("CCRA Referral Detail - Content-Type: #{response.request_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

        referral = ReferralDetail.new(response.body)
        cache_referral_data(referral, id, icn)

        referral
      end
    end

    private

    # Caches the entire referral object for future use
    #
    # @param referral [ReferralDetail] The referral data object
    # @param id [String] The referral ID
    # @param icn [String] The patient's ICN
    # @return [Boolean] True if the cache operation was successful
    def cache_referral_data(referral, id, icn)
      referral_cache.save_referral_data(
        id:,
        icn:,
        referral_data: referral
      )
    end

    # Memoized CCRA Referral cache instance
    # @return [Ccra::ReferralCache] the CCRA referral cache
    def referral_cache
      @referral_cache ||= Ccra::ReferralCache.new
    end
  end
end
