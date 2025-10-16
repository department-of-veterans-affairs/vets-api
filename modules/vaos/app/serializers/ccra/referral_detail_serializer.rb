# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :category_of_care
    attribute :expiration_date
    attribute :referral_number
    attribute :referral_consult_id
    attribute :uuid
    attribute :appointments
    attribute :referral_date
    attribute :station_id

    # Nested provider information
    attribute :provider do |referral|
      provider_info = {
        name: referral.provider_name,
        facility_name: referral.treating_facility_name,
        npi: referral.provider_npi,
        phone: referral.treating_facility_phone,
        specialty: referral.provider_specialty
      }

      # Only add address if it exists and has actual data
      address = referral.treating_facility_address
      if address.present? && address.values.any?(&:present?)
        provider_info[:address] = {
          street1: address[:street1],
          city: address[:city],
          state: address[:state],
          zip: address[:zip]
        }
      end

      # Transform keys to camelCase
      provider_info.transform_keys { |key| key.to_s.camelize(:lower).to_sym }
    end

    # Nested referring facility information
    # Use camelCase keys directly since nested attributes don't get transformed
    attribute :referring_facility do |referral|
      if referral.referring_facility_name.present?
        facility_info = {
          name: referral.referring_facility_name,
          phone: referral.referring_facility_phone,
          code: referral.referring_facility_code
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
