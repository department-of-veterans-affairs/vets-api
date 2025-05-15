# frozen_string_literal: true

module Ccra
  class ReferralDetail
    attr_reader :expiration_date, :category_of_care, :provider_name, :provider_npi,
                :provider_telephone, :treating_facility, :referral_number,
                :referring_facility_name,
                :referring_facility_phone, :referring_facility_code,
                :referring_facility_address, :has_appointments,
                :referral_date, :station_id, :referral_consult_id, :appointment_type_id,
                :treating_facility_name, :treating_facility_code, :treating_facility_phone,
                :treating_facility_address
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
      @referral_consult_id = attributes[:referral_consult_id]
      @referral_date = attributes[:referral_date]
      @station_id = attributes[:station_id]
      @uuid = nil # Will be set by controller
      @has_appointments = attributes[:appointments].present?
      # NOTE: appointment_type_id defaulted to 'ov' for phase 1 implementation, needed for EPS provider
      # slots fetching
      @appointment_type_id = 'ov'

      # Parse provider and facility info
      parse_referring_facility_info(attributes[:referring_facility_info])
      parse_treating_provider_info(attributes[:treating_provider_info])
      parse_treating_facility_info(attributes[:treating_facility_info])
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
    end

    # Parse treating facility info from the CCRA response
    #
    # @param facility_info [Hash] The treating facility info from the CCRA response
    def parse_treating_facility_info(facility_info)
      return if facility_info.blank?

      @treating_facility_name = facility_info[:facility_name]
      @treating_facility_code = facility_info[:facility_code]
      @treating_facility_phone = facility_info[:phone]
      # Parse address information
      if facility_info[:address].present?
        @treating_facility_address = {
          street1: facility_info[:address][:address1],
          city: facility_info[:address][:city],
          state: facility_info[:address][:state],
          zip: facility_info[:address][:zip_code]
        }
      end
    end
  end
end
