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
      Rails.cache.read('token', namespace: 'eps-access-token')
    end

    # Saves the token to the Redis cache.
    #
    # @param token [String] the token to be saved
    # @return [Boolean] true if the write was successful, otherwise false
    def save_token(token:)
      Rails.cache.write(
        'token',
        token,
        namespace: 'eps-access-token',
        expires_in: REDIS_CONFIG[:eps_access_token][:each_ttl]
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

    # Saves referral data directly to the Redis cache.
    # The data is stored using the referral_number from the referral_data hash.
    # The data is stored as a Ruby hash.
    #
    # @param referral_data [Hash] The referral data to be cached
    # @return [Boolean] True if the cache operation was successful
    def save_referral_data(referral_data:)
      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_data[:referral_number]}",
        referral_data,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    # Fetches a specific attribute for a given referral number.
    # Retrieves the attribute directly from the cached hash.
    #
    # @param referral_number [String] the referral number
    # @param attribute [Symbol] the attribute to be fetched
    # @return [Object, nil] the attribute value if it exists, otherwise nil
    def fetch_attribute(referral_number:, attribute:)
      data = referral_identifiers(referral_number:)
      return nil if data.nil?

      data[attribute]
    end

    # Retrieves all stored attributes for a given referral number from the Redis cache.
    # Returns the entire cached hash for the referral.
    #
    # @param referral_number [String] The referral number associated with the cached data
    # @return [Hash, nil] The complete referral data hash if it exists, otherwise nil
    def fetch_referral_attributes(referral_number:)
      referral_identifiers(referral_number:)
    end

    private

    # Retrieves the referral data hash for a given referral number from the Redis cache.
    # Uses memoization to avoid repeated cache lookups for the same referral number.
    #
    # @param referral_number [String] the referral number
    # @return [Hash, nil] the referral data hash if it exists, otherwise nil
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
