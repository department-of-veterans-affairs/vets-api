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
    # @return [Array, Hash] Parsed JSON response (typically an array of referral objects)
    def get_vaos_referral_list(icn, referral_status)
      data = { ICN: icn, ReferralStatus: referral_status }
      with_monitoring do
        response = perform(
          :post,
          "/#{config.base_path}/VAOS/patients/ReferralList",
          data,
          headers
        )
        OpenStruct.new(response.body)
      end
    end

    # Retrieves detailed Referral information.
    #
    # @param id [String] The ID of the referral.
    # @param mode [String] The mode of the referral.
    #
    # @return [Hash] Parsed JSON response with referral details.
    def get_referral(id, mode)
      data = { Id: id, Mode: mode }
      with_monitoring do
        response = perform(
          :post,
          "/#{config.base_path}/ReferralUtil/GetReferral",
          data,
          headers
        )
        OpenStruct.new(response.body)
      end
    end
  end
end
