# frozen_string_literal: true

module ClaimsApi
  class ServiceBranchMapper
    REQUIRES_MAPPING = [
      'Air Force Civilian',
      'Army Air Corps',
      'Army Nurse Corps',
      'Commonwealth Army Veteran',
      'Guerrilla Combination Service',
      'Marine',
      'National Oceanic and Atmospheric Administration',
      'National Oceanic &amp; Atmospheric Administration',
      'Regular Philippine Scout',
      'Regular Scout Service',
      'Special Philippine Scout',
      'Unknown',
      'Woman Air Corps'
    ].freeze

    MAPS_TO_OTHER = [
      'Air Force Civilian',
      'Commonwealth Army Veteran',
      'Guerrilla Combination Service',
      'Regular Philippine Scout',
      'Regular Scout Service',
      'Special Philippine Scout',
      'Unknown',
      'Woman Air Corps'
    ].freeze

    MAPS_TO_ARMY_AIR_CORPS_OR_ARMY_AIR_FORCE = [
      'Army Air Corps'
    ].freeze

    MAPS_TO_ARMY = [
      'Army Nurse Corps'
    ].freeze

    MAPS_TO_MARINE_CORPS = [
      'Marine'
    ].freeze

    MAPS_TO_NOAA_WITH_AMPERSAND = [
      'National Oceanic and Atmospheric Administration',
      'National Oceanic &amp; Atmospheric Administration'
    ].freeze

    def initialize(service_branch)
      @service_branch = service_branch
    end

    def value
      return @service_branch unless REQUIRES_MAPPING.include?(@service_branch)

      return 'Other' if MAPS_TO_OTHER.include?(@service_branch)
      return 'Army Air Corps or Army Air Force' if MAPS_TO_ARMY_AIR_CORPS_OR_ARMY_AIR_FORCE.include?(@service_branch)
      return 'Army' if MAPS_TO_ARMY.include?(@service_branch)
      return 'Marine Corps' if MAPS_TO_MARINE_CORPS.include?(@service_branch)

      'National Oceanic & Atmospheric Administration' if MAPS_TO_NOAA_WITH_AMPERSAND.include?(@service_branch)
    end
  end
end
