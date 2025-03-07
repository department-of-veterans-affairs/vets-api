# frozen_string_literal: true

module Ccra
  # Serializer for referral list entries
  # Used by the ReferralsController to serialize lists of referrals
  class ReferralListSerializer
    include JSONAPI::Serializer

    set_type :referrals

    # Serialize each referral list entry as an array
    def initialize(referrals)
      @referrals = referrals || []
    end

    def as_json(*)
      @referrals.map do |referral|
        {
          id: referral.referral_id,
          type_of_care: referral.type_of_care,
          expiration_date: referral.expiration_date&.strftime('%Y-%m-%d')
        }.compact
      end
    end
  end
end
