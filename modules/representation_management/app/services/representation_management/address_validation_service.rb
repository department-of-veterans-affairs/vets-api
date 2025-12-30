# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/v3/service'

module RepresentationManagement
  # Service class responsible for validating addresses using VAProfile Address Validation API
  #
  # This service handles:
  # - Building VAProfile ValidationAddress objects from address hashes
  # - Calling the VAProfile Address Validation V3 API
  # - Implementing retry logic for problematic addresses (e.g., P.O. Boxes mixed with street addresses)
  # - Transforming VAProfile API responses into AccreditedIndividual model attributes
  #
  # @example Basic usage
  #   service = RepresentationManagement::AddressValidationService.new
  #   address_hash = {
  #     'address_line1' => '123 Main St',
  #     'city' => 'Denver',
  #     'state_code' => 'CO',
  #     'zip_code' => '80202'
  #   }
  #   validated_attrs = service.validate_address(address_hash)
  #   # => { address_line1: '123 Main St', city: 'Denver', lat: 39.7392, ... }
  class AddressValidationService
    # Maximum number of retry attempts for address validation
    DEFAULT_MAX_RETRIES = 3

    # @param validation_service [VAProfile::AddressValidation::V3::Service, nil]
    #   Optional validation service instance (useful for testing)
    # @param max_retries [Integer] Maximum number of retry attempts
    def initialize(validation_service: nil, max_retries: DEFAULT_MAX_RETRIES)
      @validation_service = validation_service
      @max_retries = max_retries
    end

    # Main entry point - validates an address hash and returns model attributes
    #
    # @param address_hash [Hash] Address data with string keys:
    #   - 'address_line1' [String, nil]
    #   - 'address_line2' [String, nil]
    #   - 'address_line3' [String, nil]
    #   - 'city' [String, nil]
    #   - 'state_code' [String, nil]
    #   - 'zip_code' [String, nil]
    #   - 'zip_code4' [String, nil]
    #   - 'country_code_iso3' [String, nil]
    # @return [Hash, nil] Validated address attributes ready for AccreditedIndividual.update,
    #   or nil if validation fails
    def validate_address(address_hash)
      return nil if address_hash.blank?

      api_response = get_best_address_candidate(address_hash)
      return nil if api_response.nil?

      build_address_attributes(api_response)
    rescue Common::Exceptions::BackendServiceException => e
      Rails.logger.error("VAProfile address validation API error: #{e.message}")
      nil
    rescue => e
      Rails.logger.error("Address validation error: #{e.message}")
      nil
    end

    # Builds a VAProfile ValidationAddress object from an address hash
    #
    # Uses RepresentationManagement::AddressPreprocessor to normalize PO Boxes and suite/room information
    #
    # @param address_hash [Hash] Address data with string keys
    # @return [VAProfile::Models::ValidationAddress]
    def build_validation_address(address_hash)
      cleaned = RepresentationManagement::AddressPreprocessor.clean(address_hash)

      VAProfile::Models::ValidationAddress.new(
        address_pou: cleaned['address_pou'] || address_hash['address_pou'] || 'RESIDENCE',
        address_line1: cleaned['address_line1'],
        address_line2: cleaned['address_line2'],
        address_line3: cleaned['address_line3'],
        city: cleaned['city'],
        state_code: cleaned['state_code'],
        zip_code: cleaned['zip_code'],
        zip_code_suffix: cleaned['zip_code4'],
        country_code_iso3: cleaned['country_code_iso3']
      )
    end

    # Calls the VAProfile Address Validation V3 API
    #
    # @param candidate_address [VAProfile::Models::ValidationAddress]
    # @return [Hash] API response containing candidate addresses
    def call_validation_api(candidate_address)
      validation_service.candidate(candidate_address)
    end

    # Orchestrates validation with retry logic for problematic addresses
    #
    # This method attempts to validate an address and implements retry logic
    # for cases where validation returns zero coordinates (typically with
    # P.O. Box addresses mixed with street addresses), invalid responses, or
    # CandidateAddressNotFound (ADDRVAL108) backend errors.
    #
    # @param address_hash [Hash] Address data with string keys
    # @return [Hash, nil] Best validation response found, or nil if all attempts fail
    def get_best_address_candidate(address_hash)
      candidate_address = build_validation_address(address_hash)

      begin
        original_response = call_validation_api(candidate_address)
      rescue Common::Exceptions::BackendServiceException => e
        # For ADDRVAL108 / CandidateAddressNotFound, apply the same retry
        # logic as Representatives::Update before giving up
        return handle_candidate_address_not_found(address_hash, e) if candidate_address_not_found_error?(e)

        # Re-raise for non-retriable backend errors so outer rescue can handle/log
        raise
      end

      # If the original response is blank, invalid, or has zero coords, attempt retry logic
      if retriable?(original_response)
        retry_response = retry_validation(address_hash)
        return retriable?(retry_response) ? nil : retry_response
      end

      # If we get here the original response was valid and not retriable (e.g. has non-zero coords)
      original_response
    end

    # Implements retry logic for addresses that return zero coordinates or invalid responses
    #
    # When address validation returns (0,0) coordinates or no usable candidates, this method retries validation
    # using each address line individually. This handles cases where multiple address
    # lines are present and some cannot be geocoded (such as P.O. Boxes mixed with
    # street addresses).
    #
    # Retry strategy:
    # 1. First retry: Use only address_line1 from original
    # 2. Second retry: Use address_line2 as address_line1
    # 3. Third retry: Use address_line3 as address_line1
    #
    # @param address_hash [Hash] Original address data
    # @return [Hash, nil] First successful validation response, or nil if all retries fail
    def retry_validation(address_hash)
      api_response = nil
      attempts = %w[address_line1 address_line2 address_line3]

      attempts.each_with_index do |line_key, idx|
        attempt_number = idx + 1
        next unless address_hash[line_key].present? && retriable?(api_response)

        begin
          api_response = modified_validation(address_hash, attempt_number)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error("Address validation retry attempt #{attempt_number}
            (using #{line_key}) failed: #{e.message} [retry strategy: single address line]")
        end
      end

      api_response
    end

    # Transforms a VAProfile API response into AccreditedIndividual model attributes
    #
    # @param api_response [Hash] Response from VAProfile containing candidate_addresses
    # @return [Hash] Attributes ready for AccreditedIndividual.update
    def build_address_attributes(api_response)
      return {} if api_response.blank? || !api_response.key?('candidate_addresses')

      address = api_response['candidate_addresses'].first
      return {} if address.blank?

      build_v3_address(address)
    end

    # Checks if the address validation response contains valid addresses
    #
    # @param response [Hash, nil] API response
    # @return [Boolean] true if response contains candidate addresses
    def address_valid?(response)
      response.present? && response.key?('candidate_addresses') && !response['candidate_addresses'].empty?
    end

    # Checks if the geocode coordinates are both zero
    #
    # Zero coordinates typically indicate a DualAddressError warning from
    # the validator, often seen with P.O. Box addresses that mix street addresses.
    #
    # @param response [Hash, nil] API response
    # @return [Boolean] true if latitude and longitude are both zero
    def lat_long_zero?(response)
      return false if response.blank?

      address = response['candidate_addresses']&.first
      return false if address.blank?

      geocode = address['geocode']
      return false if geocode.blank?

      geocode['latitude']&.zero? && geocode['longitude']&.zero?
    end

    # Determines if a validation response warrants a retry
    #
    # A response is retriable if:
    # - The response is blank/nil
    # - The address is invalid (no candidate addresses)
    # - The coordinates are zero
    #
    # @param response [Hash, nil] API response
    # @return [Boolean] true if validation should be retried
    def retriable?(response)
      return true if response.blank?

      !address_valid?(response) || lat_long_zero?(response)
    end

    private

    # Returns the validation service instance
    #
    # @return [VAProfile::AddressValidation::V3::Service]
    def validation_service
      @validation_service ||= VAProfile::AddressValidation::V3::Service.new
    end

    # Performs a modified validation attempt using different address line combinations
    #
    # @param address_hash [Hash] Original address data
    # @param retry_count [Integer] The retry attempt number (1-3)
    # @return [Hash] API response from modified validation attempt
    def modified_validation(address_hash, retry_count)
      address_attempt = address_hash.dup

      case retry_count
      when 1
        # Use only the original address_line1 (as-is)
      when 2
        # Set address_line1 to the original address_line2
        address_attempt['address_line1'] = address_hash['address_line2']
      when 3
        # Set address_line1 to the original address_line3
        address_attempt['address_line1'] = address_hash['address_line3']
      end

      # Clear out other address lines for the retry
      address_attempt['address_line2'] = nil
      address_attempt['address_line3'] = nil

      candidate_address = build_validation_address(address_attempt)
      call_validation_api(candidate_address)
    end

    # Builds address attributes from a V3 API response
    #
    # Maps VAProfile V3 API response fields to AccreditedIndividual model attributes
    #
    # @param address [Hash] First candidate address from API response
    # @return [Hash] Model attributes
    def build_v3_address(address)
      lat = address.dig('geocode', 'latitude')
      long = address.dig('geocode', 'longitude')

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
        lat:,
        long:,
        location: lat && long ? "POINT(#{long} #{lat})" : nil
      }
    end

    # Determine if the backend exception represents a candidate address not found scenario
    #
    # Mirrors Representatives::Update#candidate_address_not_found_error?
    #
    # @param exception [Common::Exceptions::BackendServiceException]
    # @return [Boolean]
    def candidate_address_not_found_error?(exception)
      msg = exception.message
      msg.include?('CandidateAddressNotFound') || msg.include?('ADDRVAL108')
    end

    # Handle CandidateAddressNotFound errors (ADDRVAL108) by invoking modified retry logic
    #
    # @param address_hash [Hash]
    # @param exception [Common::Exceptions::BackendServiceException]
    # @return [Hash, nil]
    def handle_candidate_address_not_found(address_hash, exception)
      Rails.logger.error(
        'VAProfile address validation CandidateAddressNotFound for address: ' \
        "#{address_hash.slice('city', 'state_code', 'zip_code').inspect}: #{exception.message}, retrying..."
      )

      retry_response = retry_validation(address_hash)
      retriable?(retry_response) ? nil : retry_response
    end
  end
end
