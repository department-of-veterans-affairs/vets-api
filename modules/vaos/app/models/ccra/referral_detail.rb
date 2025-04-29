# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expiration_date, :category_of_care, :provider_name, :provider_npi,
                :provider_telephone, :treating_facility, :referral_number,
                :phone_number, :referring_facility_name,
                :referring_facility_phone, :referring_facility_code,
                :referring_facility_address, :has_appointments,
                :referral_date, :station_id
    attr_accessor :uuid

    ##
    # Initializes a new instance of ReferralDetail.
    #
    # @param attributes [Hash] A hash containing the referral details from the CCRA response.
    # @option attributes [Hash] :referral The main referral data container.
    def initialize(attributes)
      return if attributes.blank?

      @expiration_date = attributes[:referral_expiration_date]
      @category_of_care = attributes[:category_of_care]
      @treating_facility = attributes[:treating_facility]
      @referral_number = attributes[:referral_number]
      @referral_date = attributes[:referral_date]
      @station_id = attributes[:station_id]
      @uuid = nil # Will be set by controller
      @has_appointments = attributes[:appointments].present?

      # Get phone number from treating facility or provider info
      treating_facility_info = attributes[:treating_facility_info]
      treating_provider_info = attributes[:treating_provider_info]

      @phone_number = treating_facility_info&.dig(:phone).presence || treating_provider_info&.dig(:telephone).presence

      # Parse provider and facility info
      parse_referring_facility_info(attributes[:referring_facility_info])
      parse_treating_provider_info(treating_provider_info)
    end

    private

    # Parse referring facility info from the CCRA response
    #
    # @param facility_info [Hash] The facility info from the CCRA response
    def parse_referring_facility_info(facility_info)
      return if facility_info.blank?

      @referring_facility_name = facility_info[:facility_name]
      @referring_facility_phone = facility_info[:phone]
      @referring_facility_code = facility_info[:facility_code]

      # Parse address information
      if facility_info[:address].present?
        @referring_facility_address = {
          street1: facility_info[:address][:address1],
          city: facility_info[:address][:city],
          state: facility_info[:address][:state],
          zip: facility_info[:address][:zip_code]
        }
      end
    end

    # Parse treating provider info from the CCRA response
    #
    # @param provider_info [Hash] The treating provider info from the CCRA response
    def parse_treating_provider_info(provider_info)
      return if provider_info.blank?

      @provider_name = provider_info[:provider_name]
      @provider_npi = provider_info[:provider_npi]
      @provider_telephone = provider_info[:telephone]
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
