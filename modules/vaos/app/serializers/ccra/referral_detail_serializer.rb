# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_type :referral

    # Serializes the referral detail
    def initialize(referral)
      @referral = referral
    end

    def as_json(*)
      {
        id: @referral.referral_number,
        type_of_care: @referral.type_of_care,
        provider_name: @referral.provider_name,
        location: @referral.location,
        expiration_date: @referral.expiration_date
      }.compact
    end
  end
end
