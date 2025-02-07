# frozen_string_literal: true

module CCRA
  # CCRA::ReferralService provides methods for interacting with the CCRA referral endpoints.
  # It inherits from CCRA::BaseService for common REST functionality and configuration.
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
        response = perform(
          :post,
          "/#{config.base_path}/VAOS/patients/ReferralList",
          data,
          headers
        )
        ReferralListEntry.build_collection(response.body)
      end
    end

    # Retrieves detailed Referral information.
    #
    # @param id [String] The ID of the referral.
    # @param mode [String] The mode of the referral.
    #
    # @return [ReferralDetail] A ReferralDetail object representing the detailed referral information.
    def get_referral(id, mode)
      data = { Id: id, Mode: mode }
      with_monitoring do
        response = perform(
          :post,
          "/#{config.base_path}/ReferralUtil/GetReferral",
          data,
          headers
        )
        ReferralDetail.new(response.body)
      end
    end
  end
end
