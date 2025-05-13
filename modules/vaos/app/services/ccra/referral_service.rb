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
    #
    # @param id [String] The ID of the referral.
    # @param icn [String] The ICN of the patient.
    #
    # @return [ReferralDetail] A ReferralDetail object representing the detailed referral information.
    def get_referral(id, icn)
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

        referral = ReferralDetail.new(data)
        cache_referral_data(referral)
        referral
      end
    end

    private

    # Caches referral data for use in appointment creation.
    # Extracts only the necessary fields from the referral object and
    # passes them to the Redis client for storage.
    #
    # @param referral [ReferralDetail] The referral data object
    # @return [Boolean] True if the cache operation was successful, false if required data is missing
    def cache_referral_data(referral)
      referral_data = {
        referral_number: referral.referral_number,
        appointment_type_id: referral.appointment_type_id,
        end_date: referral.expiration_date,
        npi: referral.provider_npi,
        start_date: referral.referral_date
      }

      eps_redis_client.save_referral_data(referral_data:)
    end

    # Memoized EPS Redis client instance
    # @return [Eps::RedisClient] the EPS Redis client
    def eps_redis_client
      @eps_redis_client ||= Eps::RedisClient.new
    end
  end
end
