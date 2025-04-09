# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_id :referral_number
    set_type :referrals

    attribute :type_of_care
    attribute :provider_name
    attribute :location
    attribute :expiration_date

    # Include the encrypted referral ID for use in URLs
    attribute :uuid
  end
end
