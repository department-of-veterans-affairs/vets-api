# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expirationDate, :categoryOfCare, :providerName, :providerNpi,
                :providerTelephone, :treatingFacility, :referralNumber,
                :phoneNumber, :referringFacilityName,
                :referringFacilityPhone, :referringFacilityCode,
                :referringFacilityAddress, :hasAppointments,
                :referralDate, :stationId
    attr_accessor :uuid

    ##
    # Initializes a new instance of ReferralDetail.
    #
    # @param attributes [Hash] A hash containing the referral details from the CCRA response.
    def initialize(attributes)
      return if attributes.blank?

      @expirationDate = attributes['referralExpirationDate']
      @categoryOfCare = attributes['categoryOfCare']
      @treatingFacility = attributes['treatingFacility']
      @referralNumber = attributes['referralNumber']
      @referralDate = attributes['referralDate']
      @stationId = attributes['stationId']
      @uuid = nil # Will be set by controller
      @hasAppointments = attributes['appointments'].present?

      # Get phone number from treating facility or provider info
      treating_facility_info = attributes['treatingFacilityInfo']
      treating_provider_info = attributes['treatingProviderInfo']

      @phoneNumber = treating_facility_info&.dig('phone').presence || treating_provider_info&.dig('telephone').presence

      # Parse provider and facility info
      parse_referring_facility_info(attributes['referringFacilityInfo']) if attributes['referringFacilityInfo'].present?
      parse_treating_provider_info(treating_provider_info) if treating_provider_info.present?
    end

    private

    # Parse referring facility info from the CCRA response
    #
    # @param facility_info [Hash] The facility info from the CCRA response
    def parse_referring_facility_info(facility_info)
      return if facility_info.blank?

      @referringFacilityName = facility_info['facilityName']
      @referringFacilityPhone = facility_info['phone']
      @referringFacilityCode = facility_info['facilityCode']

      # Parse address information
      if facility_info['address'].present?
        @referringFacilityAddress = {
          street1: facility_info['address']['address1'],
          city: facility_info['address']['city'],
          state: facility_info['address']['state'],
          zip: facility_info['address']['zipCode']
        }
      end
    end

    # Parse treating provider info from the CCRA response
    #
    # @param provider_info [Hash] The treating provider info from the CCRA response
    def parse_treating_provider_info(provider_info)
      return if provider_info.blank?

      @providerName = provider_info['providerName']
      @providerNpi = provider_info['providerNpi']
      @providerTelephone = provider_info['telephone']
    end

    # Converts Y/N/yes/no string values to boolean
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
