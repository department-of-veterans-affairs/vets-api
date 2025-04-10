# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :category_of_care, &:type_of_care
    attribute :expiration_date
    attribute :referral_number
    attribute :uuid

    # Nested provider information
    attribute :provider do |referral|
      {
        name: referral.provider_name,
        location: referral.location
      }
    end

    # Nested referring facility information
    # Use camelCase keys directly since nested attributes don't get transformed
    attribute :referring_facility_info do |referral|
      if referral.referring_facility_name.present?
        facility_info = {
          facilityName: referral.referring_facility_name,
          phone: referral.referring_facility_phone,
          facilityCode: referral.referring_facility_code
        }

        # Only add address if it exists and has actual data
        address = referral.referring_facility_address
        if address.present? && address.values.any?(&:present?)
          # Create a new hash instead of modifying the address hash directly
          # This ensures all fields are properly included
          facility_info[:address] = {
            street1: address[:street1],
            city: address[:city],
            state: address[:state],
            zip: address[:zip]
          }
        end

        facility_info
      end
    end
  end
end
