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

    # Retrieves the provider ID for a given referral number.
    #
    # @param referral_number [String] the referral number
    # @return [String, nil] the provider ID if it exists, otherwise nil
    def provider_id(referral_number:)
      fetch_attribute(referral_number:, attribute: :provider_id)
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

    # Saves the referral information to the Redis cache.
    #
    # @param referral_number [String] the referral number
    # @param referral [Hash] the referral information to be saved
    # @return [Boolean] true if the write was successful, otherwise false
    def save(referral_number:, referral:)
      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_number}",
        referral,
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
