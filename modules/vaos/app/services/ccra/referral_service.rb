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
    # @param mode [String] The mode of the referral.
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

        ReferralDetail.new(response.body)
      end
    end
  end
end
