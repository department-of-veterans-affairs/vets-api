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
      Rails.logger.error("Geocoding error for #{self.class.name}##{geocoding_record_id}: #{e.message}")
      false
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
  end
end
