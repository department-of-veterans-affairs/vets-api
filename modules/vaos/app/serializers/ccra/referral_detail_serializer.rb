# frozen_string_literal: true

module Ccra
  # Serializer for detailed referral information
  # Used by the ReferralsController to serialize a single referral's details
  class ReferralDetailSerializer
    include JSONAPI::Serializer

    set_id :referral_number
    set_type :referral

    attribute :type_of_care
    attribute :provider_name
    attribute :location
    attribute :expiration_date
    attribute :network
    attribute :network_code
    attribute :referral_consult_id
    attribute :referral_date
    attribute :referral_last_update_datetime
    attribute :referring_facility
    attribute :referring_provider
    attribute :seoc_id
    attribute :seoc_key
    attribute :service_requested
    attribute :source_of_referral
    attribute :sta6
    attribute :station_id
    attribute :status
    attribute :treating_facility
    attribute :treating_facility_fax
    attribute :treating_facility_phone
    attribute :appointments
    attribute :referring_facility_info
    attribute :referring_provider_info
    attribute :treating_provider_info
    attribute :treating_facility_info
    attribute :treating_facility_address
  end
end
