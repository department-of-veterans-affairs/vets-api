# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expiration_date, :category_of_care, :provider_name, :provider_npi,
                :provider_telephone, :treating_facility, :referral_number,
                :phone_number, :referring_facility_name,
                :referring_facility_phone, :referring_facility_code,
                :referring_facility_address, :has_appointments,
                :referral_date, :station_id, :referral_expiration_date
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
      @referral_expiration_date = referral['ReferralExpirationDate']
      @category_of_care = referral['CategoryOfCare']
      @treating_facility = referral['TreatingFacility']
      @referral_number = referral['ReferralNumber']
      @referral_date = referral['ReferralDate']
      @station_id = referral['StationID']
      @uuid = nil # Will be set by controller
      @has_appointments = parse_boolean(referral['APPTYesNo1'])

      # Get phone number from treating facility or provider info
      treating_facility_info = referral['TreatingFacilityInfo']
      treating_provider_info = referral['TreatingProviderInfo']

      @phone_number = treating_facility_info&.dig('Phone').presence || treating_provider_info&.dig('Telephone').presence

      # Parse provider and facility info
      parse_referring_facility_info(referral['ReferringFacilityInfo']) if referral['ReferringFacilityInfo'].present?
      parse_treating_provider_info(treating_provider_info) if treating_provider_info.present?
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

    # Parse treating provider info from the CCRA response
    #
    # @param provider_info [Hash] The treating provider info from the CCRA response
    def parse_treating_provider_info(provider_info)
      return if provider_info.blank?

      @provider_name = provider_info['ProviderName']
      @provider_npi = provider_info['ProviderNPI']
      @provider_telephone = provider_info['Telephone']
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
  end
end
