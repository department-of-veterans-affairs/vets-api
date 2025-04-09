# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :type_of_care
    attribute :provider_name
    attribute :location
    attribute :expiration_date
    attribute :referral_number
    attribute :uuid
  end
end
