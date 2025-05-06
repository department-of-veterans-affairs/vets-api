# frozen_string_literal: true

require 'sidekiq'
require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'
require 'va_profile/models/v3/validation_address'
require 'va_profile/v3/address_validation/service'

module Representatives
  # Processes updates for representative records based on provided JSON data.
  # This class is designed to parse representative data, validate addresses using an external service,
  # and update records in the database accordingly. It also handles updating flagging records when a representative's
  # address, email, or phone number is updated.
  class Update
    include Sidekiq::Job

    attr_accessor :slack_messages

    def initialize
      @slack_messages = []
    end

    # Processes each representative's data provided in JSON format.
    # This method parses the JSON, validates each representative's address, and updates the database records.
    # @param reps_json [String] JSON string containing an array of representative data.
    def perform(reps_json)
      reps_data = JSON.parse(reps_json)
      reps_data.each { |rep_data| process_rep_data(rep_data) }
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

      address_validation_api_response = nil

      if rep_data['address_changed']

        api_response = get_best_address_candidate(rep_data['address'])

        # don't update the record if there is not a valid address with non-zero lat and long at this point
        if api_response.nil?
          return
        else
          address_validation_api_response = api_response
        end
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
      validation_model = if Flipper.enabled?(:remove_pciu)
                           VAProfile::Models::V3::ValidationAddress
                         else
                           VAProfile::Models::ValidationAddress
                         end

      validation_model.new(
        address_pou: address['address_pou'],
        address_line1: address['address_line1'],
        address_line2: address['address_line2'],
        address_line3: address['address_line3'],
        city: address['city'],
        state_code: address['state']['state_code'],
        zip_code: address['zip_code5'],
        zip_code_suffix: address['zip_code4'],
        country_code_iso3: address['country_code_iso3']
      )
    end

    # Validates the given address using the VAProfile address validation service.
    # @param candidate_address [VAProfile::Models::ValidationAddress] The address to be validated.
    # @return [Hash] The response from the address validation service.
    def validate_address(candidate_address)
      validation_service = if Flipper.enabled?(:remove_pciu)
                             VAProfile::V3::AddressValidation::Service.new
                           else
                             VAProfile::AddressValidation::Service.new
                           end
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
      if Flipper.enabled?(:remove_pciu)
        build_v3_address(api_response['candidate_addresses'].first)
      else
        address = api_response['candidate_addresses'].first['address']
        geocode = api_response['candidate_addresses'].first['geocode']
        meta = api_response['candidate_addresses'].first['address_meta_data']
        build_address(address, geocode, meta).merge({ raw_address: rep_data['address'].to_json })
      end
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

    def build_v3_address(address)
      {
        address_type: address['address_type'],
        address_line1: address['address_line1'],
        address_line2: address['address_line2'],
        address_line3: address['address_line3'],
        city: address['city_name'],
        province: address['state']['state_name'],
        state_code: address['state']['state_code'],
        zip_code: address['zip_code5'],
        zip_suffix: address['zip_code4'],
        country_code_iso3: address['country']['iso3_code'],
        country_name: address['country']['country_name'],
        county_name: address.dig('county', 'county_name'),
        county_code: address.dig('county', 'county_code'),
        lat: address['geocode']['latitude'],
        long: address['geocode']['longitude'],
        location: "POINT(#{address['geocode']['longitude']} #{address['geocode']['latitude']})"
      }
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
    # @param candidate_address [Hash] an address hash object returned by [VAProfile::AddressValidation::Service]
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
      return true if response.blank?

      !address_valid?(response) || lat_long_zero?(response)
    end

    # Retry address validation
    # @param rep_address [Hash] the address provided by OGC
    # @return [Hash, Nil] the response from the address validation service
    def retry_validation(rep_address)
      # the address validation service requires at least one of address_line1, address_line2, and address_line3 to
      #   exist. No need to run the retry if we know it will fail before attempting the api call.
      api_response = modified_validation(rep_address, 1) if rep_address['address_line1'].present?

      if retriable?(api_response) && rep_address['address_line2'].present?
        api_response = modified_validation(rep_address, 2)
      end

      if retriable?(api_response) && rep_address['address_line3'].present?
        api_response = modified_validation(rep_address, 3)
      end

      api_response
    end

    # Get the best address that the address validation api can provide with some retry logic added in
    # @param rep_address [Hash] the address provided by OGC
    # @return [Hash, Nil] the response from the address validation service
    def get_best_address_candidate(rep_address)
      candidate_address = build_validation_address(rep_address)
      original_response = validate_address(candidate_address)
      return nil unless address_valid?(original_response)

      # retry validation if we get zero as the coordinates - this should indicate some warning with validation that
      #   is typically seen with addresses that mix street addresses with P.O. Boxes
      if lat_long_zero?(original_response)
        retry_response = retry_validation(rep_address)

        if retriable?(retry_response)
          nil
        else
          retry_response
        end
      else
        original_response
      end
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
