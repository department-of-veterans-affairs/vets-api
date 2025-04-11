# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expiration_date, :type_of_care, :provider_name, :location,
                :referral_number, :phone_number, :referring_facility_name,
                :referring_facility_phone, :referring_facility_code,
                :referring_facility_address, :has_appointments,
                :network, :network_code, :referral_consult_id,
                :referral_date, :referral_last_update_datetime, :referring_facility,
                :referring_provider, :seoc_id, :seoc_key, :service_requested,
                :source_of_referral, :sta6, :station_id, :status, :treating_facility,
                :treating_facility_fax, :treating_facility_phone, :appointments,
                :referring_facility_info, :referring_provider_info, :treating_provider_info,
                :treating_facility_info, :treating_facility_address
    attr_accessor :uuid

    ##
    # Initializes a new instance of ReferralDetail.
    #
    # @param attributes [Hash] A hash containing the referral details from the CCRA response.
    # @option attributes [Hash] "Referral" The main referral data container.
    def initialize(attributes)
      referral = attributes['Referral']
      return if referral.blank?

      @expiration_date = referral['ReferralExpirationDate']
      @type_of_care = referral['CategoryOfCare']
      @provider_name = referral['TreatingProvider']
      @location = referral['TreatingFacility']
      @referral_number = referral['ReferralNumber']
      @phone_number = referral['ProviderPhone'] || referral['FacilityPhone']
      @uuid = nil # Will be set by controller
      @has_appointments = parse_boolean(referral['APPTYesNo1'])

      # Parse referring facility info
      parse_referring_facility_info(referral['ReferringFacilityInfo']) if referral['ReferringFacilityInfo'].present?

      assign_network_attributes(referral)
      assign_facility_and_provider_attributes(referral)
      assign_complex_nested_objects(referral)
    end

    private

    # Parse referring facility info from the CCRA response
    #
    # @param facility_info [Hash] The facility info from the CCRA response
    def parse_referring_facility_info(facility_info)
      return if facility_info.blank?

      @referring_facility_name = facility_info['FacilityName']
      @referring_facility_phone = facility_info['Phone']
      @referring_facility_code = facility_info['FacilityCode']

      # Parse address information
      if facility_info['Address'].present?
        @referring_facility_address = {
          street1: facility_info['Address']['Address1'],
          city: facility_info['Address']['City'],
          state: facility_info['Address']['State'],
          zip: facility_info['Address']['ZipCode']
        }
      end
    end

    # Converts Y/N/yes/no to boolean value
    # @param value [String] The Y or N value
    # @return [Boolean, nil] true for Y/y, false for N/n, nil otherwise
    def parse_boolean(value)
      return nil if value.blank?

      value = value.to_s.downcase
      return true if value == 'y'
      return false if value == 'n'

      nil
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
