# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expiration_date, :category_of_care, :provider_name, :location,
                :referral_number, :network, :network_code, :referral_consult_id,
                :referral_date, :referral_last_update_datetime, :referring_facility,
                :referring_provider, :seoc_id, :seoc_key, :service_requested,
                :source_of_referral, :sta6, :station_id, :status, :treating_facility,
                :treating_facility_fax, :treating_facility_phone, :appointments,
                :referring_facility_info, :referring_provider_info, :treating_provider_info,
                :treating_facility_info, :treating_facility_address

    def initialize(attributes)
      referral = attributes['Referral']
      return if referral.blank?

      assign_basic_attributes(referral)
      assign_network_attributes(referral)
      assign_facility_and_provider_attributes(referral)
      assign_complex_nested_objects(referral)
    end

    private

    def assign_basic_attributes(referral)
      @expiration_date = referral['ReferralExpirationDate'] || referral['referralExpirationDate']
      @category_of_care = referral['CategoryOfCare'] || referral['categoryOfCare']
      @provider_name = referral['TreatingProvider'] || referral['treatingProvider']
      @location = referral['TreatingFacility'] || referral['treatingFacility']
      @referral_number = referral['ReferralNumber'] || referral['referralNumber']
    end

    def assign_network_attributes(referral)
      @network = referral['network']
      @network_code = referral['networkCode']
      @referral_consult_id = referral['referralConsultId']
      @referral_date = referral['referralDate']
      @referral_last_update_datetime = referral['referralLastUpdateDateTime']
    end

    def assign_facility_and_provider_attributes(referral)
      @referring_facility = referral['referringFacility']
      @referring_provider = referral['referringProvider']
      @seoc_id = referral['seocId']
      @seoc_key = referral['seocKey']
      @service_requested = referral['serviceRequested']
      @source_of_referral = referral['sourceOfReferral']
      @sta6 = referral['sta6']
      @station_id = referral['stationId']
      @status = referral['status']
      @treating_facility = @location
      @treating_facility_fax = referral['treatingFacilityFax']
      @treating_facility_phone = referral['treatingFacilityPhone']
    end

    def assign_complex_nested_objects(referral)
      @appointments = referral['appointments']
      @referring_facility_info = referral['referringFacilityInfo']
      @referring_provider_info = referral['referringProviderInfo']
      @treating_provider_info = referral['treatingProviderInfo']
      @treating_facility_info = referral['treatingFacilityInfo']
      @treating_facility_address = referral['treatingFacilityAddress']
    end
  end
end
