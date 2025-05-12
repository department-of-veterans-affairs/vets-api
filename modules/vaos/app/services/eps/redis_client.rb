# frozen_string_literal: true

module Eps
  # RedisClient is responsible for interacting with the Redis cache
  # to store and retrieve tokens and referral information.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    def_delegators :settings, :redis_token_expiry

    # Initializes the RedisClient with settings.
    def initialize
      @settings = Settings.vaos.eps
    end

    # Retrieves the token from the Redis cache.
    #
    # @return [String, nil] the token if it exists, otherwise nil
    def token
      Rails.cache.read(
        'token',
        namespace: 'vaos-eps-cache'
      )
    end

    # Saves the token to the Redis cache.
    #
    # @param token [String] the token to be saved
    # @return [Boolean] true if the write was successful, otherwise false
    def save_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    # Retrieves the NPI (National Provider Identifier) for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @return [String, nil] the NPI if it exists, otherwise nil
    def npi(referral_number:)
      fetch_attribute(referral_number:, attribute: :npi)
    end

    # Retrieves the appointment type ID for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @return [String, nil] the appointment type ID if it exists, otherwise nil
    def appointment_type_id(referral_number:)
      fetch_attribute(referral_number:, attribute: :appointment_type_id)
    end

    # Retrieves the end date for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @return [String, nil] the end date if it exists, otherwise nil
    def end_date(referral_number:)
      fetch_attribute(referral_number:, attribute: :end_date)
    end

    # Saves referral data from a ReferralDetail object to the Redis cache.
    #
    # @param referral_id [String] The referral ID (consult ID)
    # @param referral [Ccra::ReferralDetail] The referral data object
    # @return [Boolean] True if the cache operation was successful, false if required data is missing or caching fails
    def save_referral_data(referral_id:, referral:)
      return false unless valid_referral_inputs?(referral_id, referral)

      referral_attributes = extract_referral_attributes(referral)
      return false unless required_fields_present?(referral_id, referral_attributes)

      # Directly write to cache
      cache_data = {
        data: {
          attributes: referral_attributes
        }
      }

      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_id}",
        cache_data.to_json,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    # Fetches a specific attribute for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @param attribute [Symbol] the attribute to be fetched
    # @return [Object, nil] the attribute value if it exists, otherwise nil
    def fetch_attribute(referral_number:, attribute:)
      identifiers = referral_identifiers(referral_number:)
      return nil if identifiers.nil?

      parsed_identifiers = Oj.load(identifiers).with_indifferent_access
      parsed_identifiers.dig(:data, :attributes, attribute)
    end

    # Retrieves all stored attributes for a given referral number from the Redis cache.
    #
    # @param referral_number [String] The referral number associated with the cached data.
    # @return [Hash] A hash of referral attributes if data exists, otherwise nil
    def fetch_referral_attributes(referral_number:)
      identifiers = referral_identifiers(referral_number:)
      return nil if identifiers.nil?

      parsed_identifiers = Oj.load(identifiers).with_indifferent_access
      parsed_identifiers.dig(:data, :attributes)
    end

    private

    # Validates that referral_id and referral are present
    #
    # @param referral_id [String] The referral ID
    # @param referral [Ccra::ReferralDetail] The referral object
    # @return [Boolean] True if both inputs are present
    def valid_referral_inputs?(referral_id, referral)
      if referral_id.blank? || referral.blank?
        Rails.logger.warn('Failed to cache referral data: referral_id or referral object is missing')
        return false
      end
      true
    end

    # Extracts the required attributes from the referral object
    #
    # @param referral [Ccra::ReferralDetail] The referral object
    # @return [Hash] The extracted attributes
    def extract_referral_attributes(referral)
      {
        appointment_type_id: referral.appointment_type_id,
        end_date: referral.expiration_date,
        npi: referral.provider_npi,
        start_date: referral.referral_date
      }
    end

    # Checks if all required fields are present in the attributes
    #
    # @param referral_id [String] The referral ID for logging
    # @param attributes [Hash] The referral attributes
    # @return [Boolean] True if all required fields are present
    def required_fields_present?(referral_id, attributes)
      required_fields = %i[npi appointment_type_id start_date end_date]
      missing_fields = required_fields.select { |field| attributes[field].blank? }

      if missing_fields.any?
        message = "Failed to cache referral data for ID #{referral_id}: " \
                  "missing required fields: #{missing_fields.join(', ')}"
        Rails.logger.warn(message)
        return false
      end
      true
    end

    # Retrieves the referral identifiers for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @return [String, nil] the referral identifiers if they exist, otherwise nil
    def referral_identifiers(referral_number:)
      @referral_identifiers ||= Hash.new do |h, key|
        h[key] = Rails.cache.read(
          "vaos_eps_referral_identifier_#{key}",
          namespace: 'vaos-eps-cache'
        )
      end
      @referral_identifiers[referral_number]
    end
  end
end
