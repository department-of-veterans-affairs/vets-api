# frozen_string_literal: true

module Eps
  # Eps::RedisClient provides a caching mechanism for EPS appointment data.
  # It stores and retrieves appointment IDs for background processing.
  class RedisClient
    extend Forwardable

    attr_reader :settings

    # Cache keys and namespaces
    CACHE_KEY = 'vaos_eps_appointment'
    CACHE_NAMESPACE = 'eps-appointments'

    # 26 hours to be available for the full duration of the Eps::AppointmentStatusEmailJob retries
    # which will span approximately 25 hours.
    CACHE_TTL = 26.hours

    # Initializes the RedisClient with settings.
    #
    # @return [Eps::RedisClient] A new instance of RedisClient
    def initialize
      @settings = REDIS_CONFIG[:eps_appointments]
    end

    # Store appointment status check data
    # Data is encrypted using Lockbox before storing to protect PII (email addresses)
    #
    # @param uuid [String] User's UUID
    # @param appointment_id [String] The appointment ID
    # @param email [String] User's email for notifications
    # @raise [ArgumentError] If required parameters are missing
    # @return [Boolean] True if the cache operation was successful
    def store_appointment_data(uuid:, appointment_id:, email:)
      raise ArgumentError, 'User UUID is required' if uuid.blank?
      raise ArgumentError, 'Appointment ID is required' if appointment_id.blank?
      raise ArgumentError, 'Email is required' if email.blank?

      cache_key = generate_appointment_data_key(uuid, appointment_id)
      data = { appointment_id:, email: }
      encrypted_data = encrypt_data(data)

      Rails.cache.write(
        cache_key,
        encrypted_data,
        namespace: CACHE_NAMESPACE,
        expires_in: CACHE_TTL
      )
    end

    # Retrieve appointment status check data from cache
    # Data is decrypted after retrieval using Lockbox
    # If decryption fails (old unencrypted data), returns nil (cache miss)
    #
    # @param uuid [String] User's UUID
    # @param appointment_id [String] The appointment ID
    # @return [Hash, nil] Appointment data if found and successfully decrypted
    def fetch_appointment_data(uuid:, appointment_id:)
      return if uuid.blank? || appointment_id.blank?

      cache_key = generate_appointment_data_key(uuid, appointment_id)
      encrypted_data = Rails.cache.read(cache_key, namespace: CACHE_NAMESPACE)
      return nil unless encrypted_data

      decrypt_data(encrypted_data)
    end

    private

    # Returns a configured Lockbox instance for encryption/decryption
    #
    # @return [Lockbox] A Lockbox instance with the master key
    def lockbox
      @lockbox ||= begin
        key = Settings.lockbox.master_key&.to_s
        raise ArgumentError, 'Lockbox master key is required' if key.blank?

        Lockbox.new(key:, encode: true)
      end
    end

    # Encrypts data using Lockbox before caching
    #
    # @param data [Hash] The data to encrypt
    # @return [String] The encrypted ciphertext
    def encrypt_data(data)
      lockbox.encrypt(data.to_json)
    end

    # Decrypts data retrieved from cache using Lockbox
    # Returns nil if decryption fails (handles backward compatibility with old unencrypted data)
    #
    # @param encrypted_data [String] The encrypted ciphertext
    # @return [Hash, nil] The decrypted data with symbolized keys, or nil if decryption fails
    def decrypt_data(encrypted_data)
      decrypted_json = lockbox.decrypt(encrypted_data)
      JSON.parse(decrypted_json, symbolize_names: true)
    rescue Lockbox::DecryptionError => e
      Rails.logger.warn("EPS Redis: Failed to decrypt cached data (old unencrypted data?): #{e.message}")
      nil
    end

    # Generates a consistent cache key for status check data.
    #
    # @param uuid [String] The user's UUID
    # @param appointment_id [String] The appointment ID
    # @return [String] The generated cache key
    def generate_appointment_data_key(uuid, appointment_id)
      appointment_last4 = appointment_id.to_s.last(4).presence || '0000'
      "#{CACHE_KEY}:#{uuid}:#{appointment_last4}"
    end
  end
end
