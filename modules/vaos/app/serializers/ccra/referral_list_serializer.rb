# frozen_string_literal: true

module Ccra
  # Serializer for referral list entries
  # Used by the ReferralsController to serialize lists of referrals
  class ReferralListSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :categoryOfCare, &:categoryOfCare
    attribute :referralNumber, &:referralNumber
    attribute :uuid

    # Include the expiration date formatted as YYYY-MM-DD
    attribute :expirationDate do |referral|
      referral.expirationDate&.strftime('%Y-%m-%d')
    end

    # Override to handle nil collection
    def serializable_hash(...)
      return { data: [] } unless @resource.is_a?(Array)

      super
    end
  end
end
