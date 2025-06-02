# frozen_string_literal: true

module Ccra
  class ReferralDetail
    include ActiveModel::Serializers::JSON
    include ActiveModel::Model

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
    def initialize(attributes = {})
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

    ##
    # Required for ActiveModel::Serializers::JSON
    # Returns the attributes of this model as a hash.
    #
    # @return [Hash] The attributes of this model
    def attributes
      facility_attributes.merge(referral_attributes)
    end

    # Helper method for facility-related attributes
    def facility_attributes
      {
        'referring_facility_name' => @referring_facility_name,
        'referring_facility_phone' => @referring_facility_phone,
        'referring_facility_code' => @referring_facility_code,
        'referring_facility_address' => @referring_facility_address,
        'treating_facility' => @treating_facility,
        'treating_facility_name' => @treating_facility_name,
        'treating_facility_code' => @treating_facility_code,
        'treating_facility_phone' => @treating_facility_phone,
        'treating_facility_address' => @treating_facility_address
      }
    end

    # Helper method for referral-specific attributes
    def referral_attributes
      {
        'expiration_date' => @expiration_date,
        'category_of_care' => @category_of_care,
        'provider_name' => @provider_name,
        'provider_npi' => @provider_npi,
        'referral_number' => @referral_number,
        'has_appointments' => @has_appointments,
        'referral_date' => @referral_date,
        'station_id' => @station_id,
        'referral_consult_id' => @referral_consult_id,
        'appointment_type_id' => @appointment_type_id,
        'uuid' => @uuid
      }
    end

    ##
    # Required for ActiveModel::Serializers::JSON
    # Sets the attributes from the passed-in hash.
    #
    # @param hash [Hash] The attributes to set
    def attributes=(hash)
      return if hash.blank?

      assign_basic_attributes(hash)
      assign_provider_info(hash)
      assign_facility_info(hash)
    end

    private

    # Assign basic referral attributes
    #
    # @param hash [Hash] The hash containing attributes
    def assign_basic_attributes(hash)
      @expiration_date = hash['expiration_date']
      @category_of_care = hash['category_of_care']
      @treating_facility = hash['treating_facility']
      @referral_number = hash['referral_number']
      @referral_date = hash['referral_date']
      @station_id = hash['station_id']
      @has_appointments = hash['has_appointments']
      @referral_consult_id = hash['referral_consult_id']
      @appointment_type_id = hash['appointment_type_id'] || 'ov'
      @uuid = hash['uuid']
    end

    # Assign provider information
    #
    # @param hash [Hash] The hash containing attributes
    def assign_provider_info(hash)
      @provider_name = hash['provider_name']
      @provider_npi = hash['provider_npi']
    end

    # Assign facility information including addresses
    #
    # @param hash [Hash] The hash containing attributes
    def assign_facility_info(hash)
      # Referring facility
      @referring_facility_name = hash['referring_facility_name']
      @referring_facility_phone = hash['referring_facility_phone']
      @referring_facility_code = hash['referring_facility_code']

      # Treating facility
      @treating_facility_name = hash['treating_facility_name']
      @treating_facility_code = hash['treating_facility_code']
      @treating_facility_phone = hash['treating_facility_phone']

      # Address fields with symbol keys
      if hash['referring_facility_address'].is_a?(Hash)
        @referring_facility_address = symbolize_address_keys(hash['referring_facility_address'])
      end

      if hash['treating_facility_address'].is_a?(Hash)
        @treating_facility_address = symbolize_address_keys(hash['treating_facility_address'])
      end
    end

    ##
    # Override the default from_json method to ensure address hashes have symbol keys
    #
    # @param json_string [String] JSON string to parse
    # @return [Ccra::ReferralDetail] A new ReferralDetail instance
    def self.from_json(json_string, *_args)
      from_json_with_symbolized_addresses(json_string)
    end
    private_class_method :from_json

    ##
    # Alternative approach to create from JSON that ensures address hashes have symbol keys
    #
    # @param json_string [String] JSON string to parse
    # @return [Ccra::ReferralDetail] A new ReferralDetail instance
    def self.from_json_with_symbolized_addresses(json_string)
      return nil if json_string.blank?

      begin
        # Parse the JSON
        attributes = JSON.parse(json_string)

        # Create a new instance with these attributes
        instance = new
        instance.attributes = attributes
        instance
      rescue JSON::ParserError => e
        Rails.logger.error("Error parsing ReferralDetail from JSON: #{e.message}")
        nil
      end
    end
    private_class_method :from_json_with_symbolized_addresses

    # Symbolize keys in address hashes
    #
    # @param address_hash [Hash] Hash containing address data with string keys
    # @return [Hash] Address hash with symbol keys
    def symbolize_address_keys(address_hash)
      # Convert all keys to symbols
      address_hash.transform_keys(&:to_sym)
    end

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
