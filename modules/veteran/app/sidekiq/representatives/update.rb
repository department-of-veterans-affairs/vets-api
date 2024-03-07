# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'

module Representatives
  # Processes updates for representative records based on provided JSON data.
  # This class is designed to parse representative data, validate addresses using an external service,
  # and update records in the database accordingly. It also handles updating flagging records when a representative's
  # address, email, or phone number is updated.
  class Update
    include Sidekiq::Job
    include SentryLogging

    # Processes each representative's data provided in JSON format.
    # This method parses the JSON, validates each representative's address, and updates the database records.
    # @param reps_json [String] JSON string containing an array of representative data.
    def perform(reps_json)
      reps_data = JSON.parse(reps_json)
      reps_data.each { |rep_data| process_rep_data(rep_data) }
    rescue => e
      log_error("Error processing job: #{e.message}")
    end

    private

    # Processes individual representative data, validates the address, and updates the record.
    # If the address validation fails or an error occurs during the update, the error is logged and the process
    # is halted for the current representative.
    # @param rep_data [Hash] The representative data including id and address.
    def process_rep_data(rep_data)
      return unless record_can_be_updated?(rep_data)

      address_validation_api_response = nil

      if rep_data['address_changed']
        candidate_address = build_validation_address(rep_data['address'])
        address_validation_api_response = validate_address(candidate_address)
        return unless address_valid?(address_validation_api_response)
      end

      begin
        update_rep_record(rep_data, address_validation_api_response)
      rescue Common::Exceptions::BackendServiceException => e
        log_error("Address validation failed for Rep id: #{rep_data['id']}: #{e.message}")
        return
      rescue => e
        log_error("Update failed for Rep id: #{rep_data['id']}: #{e.message}")
        return
      end

      update_flagged_records(rep_data)
    end

    def record_can_be_updated?(rep_data)
      rep_data['address_exists'] || rep_data['address_changed']
    end

    # Constructs a validation address object from the provided address data.
    # @param address [Hash] A hash containing the details of the representative's address.
    # @return [VAProfile::Models::ValidationAddress] A validation address object ready for address validation service.
    def build_validation_address(address)
      VAProfile::Models::ValidationAddress.new(
        address_pou: address['address_pou'],
        address_line1: address['address_line1'],
        address_line2: address['address_line2'],
        address_line3: address['address_line3'],
        city: address['city'],
        state_code: address['state_province']['code'],
        zip_code: address['zip_code5'],
        zip_code_suffix: address['zip_code4'],
        country_code_iso3: address['country_code_iso3']
      )
    end

    # Validates the given address using the VAProfile address validation service.
    # @param candidate_address [VAProfile::Models::ValidationAddress] The address to be validated.
    # @return [Hash] The response from the address validation service.
    def validate_address(candidate_address)
      validation_service = VAProfile::AddressValidation::Service.new
      validation_service.candidate(candidate_address)
    end

    # Checks if the address validation response is valid.
    # @param response [Hash] The response from the address validation service.
    # @return [Boolean] True if the address is valid, false otherwise.
    def address_valid?(response)
      response.key?('candidate_addresses') && !response['candidate_addresses'].empty?
    end

    # Updates the address record based on the rep_data and validation response.
    # If the record cannot be found, logs an error to Sentry.
    # @param rep_data [Hash] Original rep_data containing the address and other details.
    # @param api_response [Hash] The response from the address validation service.
    def update_rep_record(rep_data, api_response)
      record =
        Veteran::Service::Representative.find_by(representative_id: rep_data['id'])

      if record.nil?
        raise StandardError, 'Representative not found.'
      else
        address_attributes = rep_data['address_changed'] ? build_address_attributes(rep_data, api_response) : {}
        email_attributes = rep_data['email_changed'] ? build_email_attributes(rep_data) : {}
        phone_attributes = rep_data['phone_number_changed'] ? build_phone_attributes(rep_data) : {}
        record.update(merge_attributes(address_attributes, email_attributes, phone_attributes))
      end
    end

    # Updates flags for the representative's records based on changes in address, email, or phone number.
    # @param rep_data [Hash] The representative data including the id and flags for changes.
    def update_flagged_records(rep_data)
      representative_id = rep_data['id']
      update_flags(representative_id, 'address') if rep_data['address_changed']
      update_flags(representative_id, 'email') if rep_data['email_changed']
      update_flags(representative_id, 'phone_number') if rep_data['phone_number_changed']
    end

    # Updates the flags for a representative's contact data indicating a change.
    # @param representative_id [String] The ID of the representative.
    # @param flag_type [String] The type of change (address, email, or phone number).
    def update_flags(representative_id, flag_type)
      RepresentationManagement::FlaggedVeteranRepresentativeContactData
        .where(representative_id:, flag_type:,
               flagged_value_updated_at: nil)
        .update_all(flagged_value_updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
    rescue => e
      log_error("Error updating flagged records. Representative id: #{representative_id}. Flag type: #{flag_type}. Error message: #{e.message}") # rubocop:disable Layout/LineLength
    end

    # Updates the given record with the new address and other relevant attributes.
    # @param rep_data [Hash] Original rep_data containing the address and other details.
    # @param api_response [Hash] The response from the address validation service.
    def build_address_attributes(rep_data, api_response)
      address = api_response['candidate_addresses'].first['address']
      geocode = api_response['candidate_addresses'].first['geocode']
      meta = api_response['candidate_addresses'].first['address_meta_data']
      build_address(address, geocode, meta).merge({ raw_address: rep_data['address'].to_json })
    end

    def build_email_attributes(rep_data)
      { email: rep_data['email'] }
    end

    def build_phone_attributes(rep_data)
      { phone_number: rep_data['phone_number'] }
    end

    def merge_attributes(address, email, phone)
      address.merge(email).merge(phone)
    end

    # Builds the attributes for the record update from the address, geocode, and metadata.
    # @param address [Hash] Address details from the validation response.
    # @param geocode [Hash] Geocode details from the validation response.
    # @param meta [Hash] Metadata about the address from the validation response.
    # @return [Hash] The attributes to update the record with.
    def build_address(address, geocode, meta)
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
    # @param error [Exception] The error string to be logged.
    def log_error(error)
      log_message_to_sentry("Representatives::Update: #{error}", :error)
    end
  end
end
