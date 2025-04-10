# frozen_string_literal: true

module Ccra
  # Serializer for referral list entries
  # Used by the ReferralsController to serialize lists of referrals
  class ReferralListSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :category_of_care do |object|
      object.type_of_care
    end
    attribute :referral_number
    attribute :uuid

    # Include the expiration date formatted as YYYY-MM-DD
    attribute :expiration_date do |referral|
      referral.expiration_date&.strftime('%Y-%m-%d')
    end

    # Override to handle nil collection
    def serializable_hash(...)
      return { data: [] } unless @resource.is_a?(Array)

      super
    end
  end
end
