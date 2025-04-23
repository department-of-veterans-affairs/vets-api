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
      data = { ICN: icn, ReferralStatus: referral_status }
      with_monitoring do
        # Skip token authentication for mock requests
        req_headers = config.mock_enabled? ? {} : headers
        response = perform(
          :post,
          "/#{config.base_path}/#{icn}/referrals",
          data,
          req_headers
        )
        ReferralListEntry.build_collection(JSON.parse(response.body))
      end
    end

    # Retrieves detailed Referral information.
    #
    # @param id [String] The ID of the referral.
    # @param mode [String] The mode of the referral.
    #
    # @return [ReferralDetail] A ReferralDetail object representing the detailed referral information.
    def get_referral(id, mode, icn)
      data = { Id: id, Mode: mode }
      with_monitoring do
        # Skip token authentication for mock requests
        req_headers = config.mock_enabled? ? {} : headers
        response = perform(
          :post,
          "/#{config.base_path}/#{icn}/referrals/#{id}",
          data,
          req_headers
        )
        ReferralDetail.new(JSON.parse(response.body))
      end
    end
  end
end
