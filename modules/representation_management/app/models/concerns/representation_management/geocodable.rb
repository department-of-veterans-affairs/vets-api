# frozen_string_literal: true

module RepresentationManagement
  # Provides geocoding functionality for models with address fields
  # Requires the including model to have: lat, long, location, address_line1, city, state_code, zip_code
  module Geocodable
    extend ActiveSupport::Concern

    #
    # Geocodes the record's address and updates lat, long, and location fields.
    # Uses partial address information with fallback strategy.
    # @return [Boolean] true if geocoding succeeded, false otherwise
    def geocode_and_update_location!
      address = build_geocodable_address
      return false if address.blank?

      result = Geocoder.search(address).first
      return false if result.blank?

      self.lat = result.latitude
      self.long = result.longitude
      # PostGIS expects POINT(longitude latitude) - note the order!
      self.location = "POINT(#{result.longitude} #{result.latitude})"

      save!
      true
    rescue => e
      handle_geocoding_error(e)
    end

    private

    #
    # Builds a geocodable address string from available address fields.
    # Tries full address first, then city/state, then zip code only.
    # @return [String, nil] Address string suitable for geocoding, or nil if insufficient data
    def build_geocodable_address
      # Try full address first
      if address_line1.present? && city.present? && state_code.present?
        return [address_line1, city, state_code, zip_code].compact.join(', ')
      end

      # Fall back to city/state
      return [city, state_code].compact.join(', ') if city.present? && state_code.present?

      # Last resort: zip code only
      zip_code.presence
    end

    #
    # Returns the identifier used in error logging for this record.
    # Override in including models if primary key is not 'id'.
    # @return [String, Integer] The record identifier
    def geocoding_record_id
      id
    end

    #
    # Handles geocoding errors with appropriate logging and retry logic.
    # @param error [Exception] The error that occurred during geocoding
    # @return [Boolean] false for non-retryable errors
    # @raise [Exception] Re-raises retryable errors for Sidekiq retry
    def handle_geocoding_error(error)
      case error
      when Geocoder::OverQueryLimitError
        log_and_raise(error, 'rate limit', :warn)
      when Geocoder::RequestDenied
        log_error(error, 'request denied')
      when Geocoder::InvalidRequest
        log_error(error, 'invalid request')
      when Geocoder::InvalidApiKey
        log_and_raise(error, 'API key invalid', :error)
      when Geocoder::ServiceUnavailable
        log_and_raise(error, 'service unavailable', :warn)
      when SocketError, Timeout::Error
        log_and_raise(error, 'network error', :warn)
      else
        log_error(error, 'unexpected error')
      end
    end

    #
    # Logs an error and returns false (non-retryable)
    def log_error(error, error_type)
      Rails.logger.error("Geocoding #{error_type} for #{record_identifier}: #{error.message}")
      false
    end

    #
    # Logs an error and re-raises it (retryable)
    def log_and_raise(error, error_type, level)
      Rails.logger.send(level, "Geocoding #{error_type} for #{record_identifier}: #{error.message}")
      raise
    end

    #
    # Returns a string identifier for logging
    def record_identifier
      "#{self.class.name}##{geocoding_record_id}"
    end
  end
end
