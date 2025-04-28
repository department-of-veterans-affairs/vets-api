# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    set_id :uuid
    set_type :referrals

    attribute :categoryOfCare, &:categoryOfCare
    attribute :expirationDate, &:expirationDate
    attribute :referralNumber, &:referralNumber
    attribute :uuid
    attribute :hasAppointments, &:hasAppointments
    attribute :referralDate, &:referralDate
    attribute :stationId, &:stationId

    # Nested provider information
    attribute :provider do |referral|
      {
        name: referral.providerName,
        npi: referral.providerNpi,
        telephone: referral.providerTelephone,
        location: referral.treatingFacility
      }
    end

    # Nested referring facility information
    # Use camelCase keys directly since nested attributes don't get transformed
    attribute :referringFacility do |referral|
      if referral.referringFacilityName.present?
        facility_info = {
          name: referral.referringFacilityName,
          phone: referral.referringFacilityPhone,
          code: referral.referringFacilityCode
        }

        # Only add address if it exists and has actual data
        address = referral.referringFacilityAddress
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
