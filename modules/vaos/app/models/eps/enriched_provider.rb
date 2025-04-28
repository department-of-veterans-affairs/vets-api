# frozen_string_literal: true

module Eps
  # Enriches provider data with additional information from referrals
  class EnrichedProvider
    # Creates a provider object enriched with referral information
    #
    # @param provider [Object] The base provider object to enrich
    # @param referral_detail [Ccra::ReferralDetail, nil] Optional referral details to merge
    # @return [OpenStruct] Enhanced provider with referral information
    def self.from_referral(provider, referral_detail)
      return provider if provider.nil? || referral_detail&.phoneNumber.blank?

      enriched_data = provider.to_h
      enriched_data[:phone_number] = referral_detail.phoneNumber
      OpenStruct.new(enriched_data)
    end
  end
end
