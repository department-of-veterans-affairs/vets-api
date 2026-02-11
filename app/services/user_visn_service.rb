# frozen_string_literal: true

class UserVisnService
  # Hardcoded pilot VISNs for MVP - easy to update as pilot expands
  PILOT_VISNS = %w[2 15 21 20 10 19].freeze
  CACHE_KEY_PREFIX = 'va_profile:facility_visn'

  def initialize(user)
    @user = user
  end

  def in_pilot_visn?
    return false unless @user.va_treatment_facility_ids.any?

    user_visns = @user.va_treatment_facility_ids.filter_map do |facility_id|
      get_cached_visn_for_facility(facility_id)
    end

    user_visns.intersect?(PILOT_VISNS)
  end

  private

  def get_cached_visn_for_facility(facility_id)
    cache_key = "#{CACHE_KEY_PREFIX}:#{facility_id}"

    # Lazy loading with 24-hour cache
    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      fetch_visn_from_lighthouse(facility_id)
    end
  end

  def fetch_visn_from_lighthouse(facility_id)
    facilities_client = Lighthouse::Facilities::V1::Client.new

    # Use facilityIds parameter to get specific facility
    facilities = facilities_client.get_facilities(facilityIds: "vha_#{facility_id}")

    return nil if facilities.blank?

    facility = facilities.first
    return nil unless facility&.attributes

    facility_visn = facility.attributes['visn']&.to_s
    Rails.logger.info("Fetched VISN #{facility_visn} for facility #{facility_id} from Lighthouse API")
    facility_visn
  rescue => e
    Rails.logger.warn("Failed to fetch VISN for facility #{facility_id}: #{e.message}")
    nil
  end
end
