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
      address = formatted_raw_address
      return false if address.blank?

      result = Geocoder.search(address).first
      return false if result.first.blank?

      # Save any partial city/state and zip data for display
      self.city = raw_address['city'] if raw_address['city'].present?
      self.state_code = raw_address['state_code'] if raw_address['state_code'].present?
      self.zip_code = raw_address['zip_code'] if raw_address['zip_code'].present?

      self.lat = result.latitude
      self.long = result.longitude
      # PostGIS expects POINT(longitude latitude) - note the order!
      self.location = "POINT(#{result.longitude} #{result.latitude})"

      # Save fallback geolocation timestamp
      self.fallback_location_updated_at = Time.current

      save!
      true
    rescue => e
      handle_geocoding_error(e)
    end

    private

    def formatted_raw_address
      # Define logical order based on entity type
      # Not every entity type has all of these fields
      # Representatives/Attorneys: address_line1, address_line2, address_line3, city, state_code, zip_code
      # Agents: address_line1, address_line2, address_line3, zip_code, work_country

      fields = %w[address_line1 address_line2 address_line3 city state_code zip_code work_country]

      fields.map { |field| raw_address[field].to_s.strip }
            .reject(&:empty?)
            .join(' ')
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
