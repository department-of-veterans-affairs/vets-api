# frozen_string_literal: true

require 'sidekiq'
require 'va_profile/models/validation_address'
require 'va_profile/address_validation/v3/service'

module Representatives
  # Processes updates for representative records based on provided JSON data.
  # This class is designed to parse representative data, validate addresses using an external service,
  # and update records in the database accordingly. It also handles updating flagging records when a representative's
  # address, email, or phone number is updated.
  class Update
    include Sidekiq::Job

    RATE_LIMIT_SECONDS = 2

    attr_accessor :slack_messages

    def initialize
      @slack_messages = []
      @records_needing_geocoding = []
    end

    # Processes each representative's data provided in JSON format.
    # This method parses the JSON, validates each representative's address, and updates the database records.
    # @param reps_json [String] JSON string containing an array of representative data.
    def perform(reps_json)
      reps_data = JSON.parse(reps_json)
      reps_data.each { |rep_data| process_rep_data(rep_data) }
      enqueue_geocoding_jobs
    rescue => e
      log_error("Error processing job: #{e.message}", send_to_slack: true)
    ensure
      @slack_messages.unshift('Representatives::Update') if @slack_messages.any?
      log_to_slack(@slack_messages.join("\n")) unless @slack_messages.empty?
    end

    private

    # Processes individual representative data, validates the address, and updates the record.
    # If the address validation fails or an error occurs during the update, the error is logged and the process
    # is halted for the current representative.
    # @param rep_data [Hash] The representative data including id and address.
    def process_rep_data(rep_data)
      return unless record_can_be_updated?(rep_data)

      begin
        address_validation_api_response = nil

        if rep_data['address_changed']
          api_response = get_best_address_candidate(rep_data['address'])
          # If address validation fails, log and continue to update non-address fields (email/phone)
          if api_response.nil?
            log_error("Address validation failed for Rep: #{rep_data['id']}. Proceeding to update non-address fields.")
            @records_needing_geocoding << rep_data['id']
          else
            address_validation_api_response = api_response
          end
        end

        updated_flags = update_rep_record(rep_data, address_validation_api_response)
      rescue => e
        log_error("Update failed for Rep id: #{rep_data}: #{e.message}")
        return
      end

      # Update flagged records only for fields that were actually updated
      updated_flags['representative_id'] = rep_data['id'] if updated_flags.is_a?(Hash)
      update_flagged_records(updated_flags || {})
    end

    def record_can_be_updated?(rep_data)
      rep_data['address_exists'] || rep_data['address_changed']
    end

    # Constructs a validation address object from the provided address data.
    # @param address [Hash] A hash containing the details of the representative's address.
    # @return [VAProfile::Models::ValidationAddress] A validation address object ready for address validation service.
    def build_validation_address(address)
      validation_model = VAProfile::Models::ValidationAddress

      cleaned = Veteran::AddressPreprocessor.clean(address)

      validation_model.new(
        address_pou: cleaned['address_pou'] || address['address_pou'],
        address_line1: cleaned['address_line1'],
        address_line2: cleaned['address_line2'],
        address_line3: cleaned['address_line3'],
        city: cleaned['city'] || address['city'],
        state_code: cleaned.dig('state', 'state_code') || address.dig('state', 'state_code'),
        zip_code: cleaned['zip_code5'] || address['zip_code5'],
        zip_code_suffix: cleaned['zip_code4'] || address['zip_code4'],
        country_code_iso3: cleaned['country_code_iso3'] || address['country_code_iso3']
      )
    end

    # Validates the given address using the VAProfile address validation service.
    # @param candidate_address [VAProfile::Models::ValidationAddress] The address to be validated.
    # @return [Hash] The response from the address validation service.
    def validate_address(candidate_address)
      validation_service = VAProfile::AddressValidation::V3::Service.new
      validation_service.candidate(candidate_address)
    end

    # Checks if the address validation response is valid.
    # @param response [Hash] The response from the address validation service.
    # @return [Boolean] True if the address is valid, false otherwise.
    def address_valid?(response)
      response.key?('candidate_addresses') && !response['candidate_addresses'].empty?
    end

    # Updates the address record based on the rep_data and validation response.
    # If the record cannot be found, logs an error to Datadog.
    # @param rep_data [Hash] Original rep_data containing the address and other details.
    # @param api_response [Hash] The response from the address validation service.
    def update_rep_record(rep_data, api_response)
      record = Veteran::Service::Representative.find_by(representative_id: rep_data['id'])
      raise StandardError, 'Representative not found.' if record.nil?

      attributes, flags = build_rep_update_payload(rep_data, api_response)
      record.update(attributes)
      flags
    end

    # Build attributes hash and flags indicating which fields changed
    # @return [Array<Hash, Hash>] first element is attributes, second is flags
    def build_rep_update_payload(rep_data, api_response)
      flags = {}

      address_attrs = if rep_data['address_changed'] && api_response.present?
                        flags['address'] = true
                        build_address_attributes(rep_data, api_response)
                      else
                        {}
                      end

      email_attrs = if rep_data['email_changed']
                      flags['email'] = true
                      build_email_attributes(rep_data)
                    else
                      {}
                    end

      phone_attrs = if rep_data['phone_number_changed']
                      flags['phone_number'] = true
                      build_phone_attributes(rep_data)
                    else
                      {}
                    end

      [merge_attributes(address_attrs, email_attrs, phone_attrs), flags]
    end

    # Updates flags for the representative's records based on which fields were actually updated.
    # @param updated_flags [Hash] Hash with keys 'address', 'email', 'phone_number' set to true when updated.
    def update_flagged_records(updated_flags)
      return unless updated_flags.is_a?(Hash)

      representative_id = updated_flags['representative_id']

      # If representative_id is missing, we can't update flags
      return if representative_id.blank?

      update_flags(representative_id, 'address') if updated_flags['address']
      update_flags(representative_id, 'email') if updated_flags['email']
      update_flags(representative_id, 'phone_number') if updated_flags['phone_number']
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
    def build_address_attributes(_rep_data, api_response)
      build_v3_address(api_response['candidate_addresses'].first)
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
    # @return [Hash] The attributes to update the record with.
    def build_v3_address(address)
      {
        address_type: address['address_type'],
        address_line1: address['address_line1'],
        address_line2: address['address_line2'],
        address_line3: address['address_line3'],
        city: address['city_name'],
        province: address.dig('state', 'state_name'),
        state_code: address.dig('state', 'state_code'),
        zip_code: address['zip_code5'],
        zip_suffix: address['zip_code4'],
        country_code_iso3: address.dig('country', 'iso3_code'),
        country_name: address.dig('country', 'country_name'),
        county_name: address.dig('county', 'county_name'),
        county_code: address.dig('county', 'county_code'),
        lat: address.dig('geocode', 'latitude'),
        long: address.dig('geocode', 'longitude'),
        location: build_point(address.dig('geocode', 'longitude'), address.dig('geocode', 'latitude'))
      }
    end

    # Build a WKT point string if both coordinates are present
    def build_point(longitude, latitude)
      return nil if longitude.blank? || latitude.blank?

      "POINT(#{longitude} #{latitude})"
    end

    # Enqueues geocoding jobs for records that failed address validation.
    # Jobs are spaced 2 seconds apart to respect rate limiting.
    # @return [void]
    def enqueue_geocoding_jobs
      return if @records_needing_geocoding.empty?

      @records_needing_geocoding.each_with_index do |representative_id, index|
        delay_seconds = index * RATE_LIMIT_SECONDS
        model = 'Veteran::Service::Representative'
        RepresentationManagement::GeocodeRepresentativeJob.perform_in(delay_seconds.seconds,
                                                                      model, representative_id)
      end
    rescue => e
      log_error("Error enqueueing geocoding jobs: #{e.message}", send_to_slack: true)
    end

    # Logs an error to Datadog and adds an error to the array that will be logged to slack.
    # @param error [Exception] The error string to be logged.
    def log_error(error, send_to_slack: false)
      message = "Representatives::Update: #{error}"
      Rails.logger.error(message)
      @slack_messages << "----- #{message}" if send_to_slack
    end

    # Checks if the latitude and longitude of an address are both set to zero, which are the default values
    #   for DualAddressError warnings we see with some P.O. Box addresses the validator struggles with
    # @param candidate_address [Hash] an address hash object returned by [VAProfile::AddressValidation::V3::Service]
    # @return [Boolean]
    def lat_long_zero?(candidate_address)
      address = candidate_address['candidate_addresses']&.first
      return false if address.blank?

      geocode = address['geocode']
      return false if geocode.blank?

      geocode['latitude']&.zero? && geocode['longitude']&.zero?
    end

    # Attempt to get valid address with non-zero coordinates by modifying the OGC address data
    # @param address [Hash] the OGC address object
    # @param retry_count [Integer] the current retry attempt which determines how the address object should be modified
    # @return [Hash] the response from the address validation service
    def modified_validation(address, retry_count)
      address_attempt = address.dup
      case retry_count
      when 1 # only use the original address_line1
      when 2 # set address_line1 to the original address_line2
        address_attempt['address_line1'] = address['address_line2']
      else # set address_line1 to the original address_line3
        address_attempt['address_line1'] = address['address_line3']
      end

      address_attempt['address_line2'] = nil
      address_attempt['address_line3'] = nil

      validate_address(build_validation_address(address_attempt))
    end

    # An address validation attempt is retriable if the address is invalid OR the coordinates are zero
    # @param response [Hash, Nil] the response from the address validation service
    # @return [Boolean]
    def retriable?(response)
      response.blank? || !address_valid?(response) || lat_long_zero?(response)
    end

    # Retry address validation
    # @param rep_address [Hash] the address provided by OGC
    # @return [Hash, Nil] the response from the address validation service
    def retry_validation(rep_address)
      # the address validation service requires at least one of address_line1, address_line2, and address_line3 to
      #   exist. No need to run the retry if we know it will fail before attempting the api call.
      api_response = nil
      attempts = %w[address_line1 address_line2 address_line3]

      attempts.each_with_index do |line_key, idx|
        attempt_number = idx + 1
        line_present = rep_address[line_key].present?
        next unless line_present && retriable?(api_response)

        begin
          api_response = modified_validation(rep_address, attempt_number)
        rescue Common::Exceptions::BackendServiceException => e
          log_error("Attempt #{attempt_number} failed: #{e.message}")
        end
      end

      api_response
    end

    # Get the best address that the address validation api can provide with some retry logic added in
    # @param rep_address [Hash] the address provided by OGC
    # @return [Hash, Nil] the response from the address validation service
    def get_best_address_candidate(rep_address)
      candidate_address = build_validation_address(rep_address)
      original_response = nil
      begin
        original_response = validate_address(candidate_address)
      rescue Common::Exceptions::BackendServiceException => e
        return handle_candidate_address_not_found(rep_address, e) if candidate_address_not_found_error?(e)

        # Re-raise for non-retriable backend errors so outer rescue can handle/log
        raise
      end

      # If the original response is blank, invalid, or has zero coords, attempt retry logic which will
      # try modified address lines (including preprocessor-extracted PO Box) before giving up.
      if retriable?(original_response)
        retry_response = retry_validation(rep_address)

        return retriable?(retry_response) ? nil : retry_response
      end

      # If we get here the original response was valid and not retriable (e.g. has non-zero coords)
      original_response
    end

    # Determine if the backend exception represents a candidate address not found scenario
    # @param exception [Common::Exceptions::BackendServiceException]
    # @return [Boolean]
    def candidate_address_not_found_error?(exception)
      msg = exception.message
      msg.include?('CandidateAddressNotFound') || msg.include?('ADDRVAL108')
    end

    # Handle CandidateAddressNotFound errors (ADDRVAL108) by invoking modified retry logic
    # @param rep_address [Hash]
    # @param exception [Common::Exceptions::BackendServiceException]
    # @return [Hash, Nil]
    def handle_candidate_address_not_found(rep_address, exception)
      log_error("Address validation failed for address: #{rep_address}: #{exception.message}, retrying...")
      retry_response = retry_validation(rep_address)
      retriable?(retry_response) ? nil : retry_response
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'Representatives::Update Bot')
      client.notify(message)
    end
  end
end
