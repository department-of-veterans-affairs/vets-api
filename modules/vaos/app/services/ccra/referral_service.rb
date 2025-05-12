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
        # Skip token authentication for mock requests
        req_headers = config.mock_enabled? ? {} : headers

        response = perform(
          :get,
          "/#{config.base_path}/#{icn}/referrals",
          params,
          req_headers
        )

        # Log the response body for debugging purposes, will remove upon completion of staging testing
        body_preview = response.body.is_a?(String) ? response.body : response.body.inspect
        Rails.logger.info("CCRA Referral List - Req headers: #{req_headers}")
        Rails.logger.info("CCRA Referral List - Params: #{params}")
        Rails.logger.info("CCRA Referral List - Content-Type: #{response.response_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

        # Note JSON.parse is only used for betamock responses
        data = response.body.is_a?(String) ? JSON.parse(response.body, symbolize_names: true) : response.body

        ReferralListEntry.build_collection(data)
      end
    end

    # Retrieves detailed Referral information.
    #
    # @param id [String] The ID of the referral.
    # @param mode [String] The mode of the referral.
    #
    # @return [ReferralDetail] A ReferralDetail object representing the detailed referral information.
    def get_referral(id, icn)
      params = {}
      with_monitoring do
        # Skip token authentication for mock requests
        req_headers = config.mock_enabled? ? {} : headers
        response = perform(
          :get,
          "/#{config.base_path}/#{icn}/referrals/#{id}",
          params,
          req_headers
        )

        # Log the response body for debugging purposes, will remove upon completion of staging testing
        body_preview = response.body.is_a?(String) ? response.body[0..100] : response.body.inspect[0..100]
        Rails.logger.info("CCRA Referral Detail - Req headers: #{req_headers}")
        Rails.logger.info("CCRA Referral Detail - Params: #{params}")
        Rails.logger.info("CCRA Referral Detail - Content-Type: #{response.request_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

        # Note JSON.parse is only used for betamock responses
        data = response.body.is_a?(String) ? JSON.parse(response.body, symbolize_names: true) : response.body

        referral = ReferralDetail.new(data)
        cache_referral_data(id, referral)
        referral
      end
    end

    private

    # Caches referral data for use in appointment creation
    #
    # @param referral_id [String] The referral ID (consult ID)
    # @param referral [ReferralDetail] The referral data object
    # @return [Boolean] True if the cache operation was successful, false if required data is missing or caching fails
    def cache_referral_data(referral_id, referral)
      # Delegate to the RedisClient's save_referral_data method
      eps_redis_client.save_referral_data(referral_id:, referral:)
    end

    # Memoized EPS Redis client instance
    # @return [Eps::RedisClient] the EPS Redis client
    def eps_redis_client
      @eps_redis_client ||= Eps::RedisClient.new
    end
  end
end
