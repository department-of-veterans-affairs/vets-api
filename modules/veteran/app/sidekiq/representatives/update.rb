# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'

module Representatives
  # A Sidekiq job class for updating address records. It processes JSON data for address updates,
  # validates the address, and then updates the address record if valid.
  class Update
    include Sidekiq::Job
    include SentryLogging

    # Performs the job of parsing JSON data, validating the address, and updating the record.
    # @param json_data [String] JSON string containing address data.
    def perform(json_data)
      data = JSON.parse(json_data)
      validation_address = build_validation_address(data['request_address'])
      response = validate_address(validation_address)

      return unless address_valid?(response)

      update_address_record(data, response)
    rescue JSON::ParserError => e
      log_error(e)
    end

    private

    # Builds a validation address object from the provided address data.
    # @param request_address [Hash] A hash containing address fields.
    # @return [VAProfile::Models::ValidationAddress] A validation address object.
    def build_validation_address(request_address)
      VAProfile::Models::ValidationAddress.new(
        address_pou: request_address['address_pou'],
        address_line1: request_address['address_line1'],
        address_line2: request_address['address_line2'],
        address_line3: request_address['address_line3'],
        city: request_address['city'],
        state_code: request_address['state_province']['code'],
        zip_code: request_address['zip_code5'],
        zip_code_suffix: request_address['zip_code4'],
        country_code_iso3: request_address['country_code_iso3']
      )
    end

    # Validates the given address using the VAProfile address validation service.
    # @param validation_address [VAProfile::Models::ValidationAddress] The address to be validated.
    # @return [Hash] The response from the address validation service.
    def validate_address(validation_address)
      validation_service = VAProfile::AddressValidation::Service.new
      validation_service.candidate(validation_address)
    end

    # Checks if the address validation response is valid.
    # @param response [Hash] The response from the address validation service.
    # @return [Boolean] True if the address is valid, false otherwise.
    def address_valid?(response)
      response.key?('candidate_addresses') && !response['candidate_addresses'].empty?
    end

    # Updates the address record based on the data and validation response.
    # If the record cannot be found, logs an error to Sentry.
    # @param data [Hash] Original data containing the address and other details.
    # @param api_response [Hash] The response from the address validation service.
    def update_address_record(data, api_response)
      record =
        Veteran::Service::Representative.find_by(representative_id: data['id'])

      if record.nil?
        log_message_to_sentry(
          "Update record not found for representative with id: #{data['id']}",
          :error
        )
      else
        update_record(record, data, api_response)
      end
    end

    # Updates the given record with the new address and other relevant attributes.
    # @param record [ActiveRecord::Base] The record to be updated.
    # @param data [Hash] Original data containing the address and other details.
    # @param api_response [Hash] The response from the address validation service.
    def update_record(record, data, api_response)
      address = api_response['candidate_addresses'].first['address']
      geocode = api_response['candidate_addresses'].first['geocode']
      meta = api_response['candidate_addresses'].first['address_meta_data']
      record_attributes = build_record_attributes(address, geocode, meta)
                          .merge({ raw_address: data['request_address'].to_json })
      record_attributes[:email] = data['email_address']
      record_attributes[:phone_number] = data['phone_number']
      record.update(record_attributes)
    end

    # Builds the attributes for the record update from the address, geocode, and metadata.
    # @param address [Hash] Address details from the validation response.
    # @param geocode [Hash] Geocode details from the validation response.
    # @param meta [Hash] Metadata about the address from the validation response.
    # @return [Hash] The attributes to update the record with.
    def build_record_attributes(address, geocode, meta)
      {
        address_type: meta['address_type'],
        address_line1: address['address_line1'],
        address_line2: address['address_line2'],
        address_line3: address['address_line3'],
        city: address['city'],
        province: address['state_province']['name'],
        state_code: address['state_province']['code'],
        zip_code: address['zip_code5'],
        zip_suffix: address['zip_code4'],
        country_code_iso3: address['country']['iso3_code'],
        country_name: address['country']['name'],
        county_name: address.dig('county', 'name'),
        county_code: address.dig('county', 'county_fips_code'),
        lat: geocode['latitude'],
        long: geocode['longitude'],
        location: "POINT(#{geocode['longitude']} #{geocode['latitude']})"
      }
    end

    # Logs an error to Sentry.
    # @param error [Exception] The error object to be logged.
    def log_error(error)
      log_message_to_sentry("Update error: #{error.message}", :error)
    end
  end
end
