# frozen_string_literal: true

module Ccra
  # Serializer for referral list entries
  # Used by the ReferralsController to serialize lists of referrals
  class ReferralListSerializer
    include JSONAPI::Serializer

    set_id :referral_id
    set_type :referrals

    attribute :type_of_care

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
