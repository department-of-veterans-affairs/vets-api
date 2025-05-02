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
        Rails.logger.info("CCRA Referral List - Content-Type: #{response.response_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

        data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body

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
        Rails.logger.info("CCRA Referral Detail - Content-Type: #{response.request_headers['Content-Type']}, " \
                          "Body Class: #{response.body.class}, Body Preview: #{body_preview}...")

        data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body

        ReferralDetail.new(data)
      end
    end
  end
end
