# frozen_string_literal: true

module RepresentationManagement
  # Provides geocoding functionality for models with address fields
  # Requires the including model to have: lat, long, location, address_line1, city, state_code, zip_code
  module Geocodable
    extend ActiveSupport::Concern

    #
    # Geocodes the record's address and updates lat, long, and location fields.
    # Uses partial address information with fallback strategy.
    # @return [Boolean] true if geocoding succeeded, false if skipped or failed
    def geocode_and_update_location!
      # Early return if Mapbox API key is not configured
      return false if Geocoder.config.api_key.blank?

      address = formatted_raw_address
      return false if address.blank?

      result = Geocoder.search(address).first
      return false if result.blank?

      clear_location_fields

      # Save any partial city/state and zip data for display if raw_address exists
      if raw_address.present?
        self.city = raw_address['city'] if raw_address['city'].present?
        self.state_code = raw_address['state_code'] if raw_address['state_code'].present?
        self.zip_code = raw_address['zip_code'] if raw_address['zip_code'].present?
      end

      self.lat = result.latitude
      self.long = result.longitude
      # PostGIS expects POINT(longitude latitude) - note the order!
      self.location = "POINT(#{result.longitude} #{result.latitude})"

      # Save fallback geolocation timestamp
      self.fallback_location_updated_at = Time.current

      save!
      true
    rescue Geocoder::Error, SocketError, Timeout::Error => e
      handle_geocoding_error(e)
    end

    private

    #
    # Clears all address and location fields to ensure fresh data
    def clear_location_fields
      # Location fields
      self.lat = nil
      self.long = nil
      self.location = nil

      # Address fields
      self.address_line1 = nil
      self.address_line2 = nil
      self.address_line3 = nil
      self.city = nil
      self.country_code_iso3 = nil
      self.country_name = nil
      self.county_name = nil
      self.county_code = nil
      self.international_postal_code = nil
      self.province = nil
      self.state_code = nil
      self.zip_code = nil
      self.zip_suffix = nil
    end

    def formatted_raw_address
      # Define logical order based on entity type
      # Not every entity type has all of these fields
      # Representatives/Attorneys: address_line1, address_line2, address_line3, city, state_code, zip_code
      # Agents: address_line1, address_line2, address_line3, zip_code, work_country

      # Use raw_address hash if available, otherwise use model attributes directly
      address_hash = raw_address || {}
      fields = %w[address_line1 address_line2 address_line3 city state_code zip_code work_country]

      # Build address from hash or attributes
      parts = fields.map do |field|
        value = address_hash[field] || (respond_to?(field) ? send(field) : nil)
        value.to_s.strip
      end

      parts.reject(&:empty?).join(' ').presence
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
        log_error(error, 'API key invalid')
      when Geocoder::ServiceUnavailable
        log_and_raise(error, 'service unavailable', :warn)
      when SocketError, Timeout::Error
        log_and_raise(error, 'network error', :warn)
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
