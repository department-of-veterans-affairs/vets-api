# frozen_string_literal: true

module ClaimsApi
  class ServiceBranchMapper
    OLD_VALUES = [
      'Air Force Academy',
      'Air Force Reserves',
      'Army Reserves',
      'Army Air Corps or Army Air Force',
      'Army Nurse Corps',
      'Coast Guard Academy',
      'Coast Guard Reserves',
      'Marine Corps',
      'Marine Corps Reserves',
      'Merchant Marine',
      'Naval Academy',
      'Navy Reserves',
      'Other',
      'US Military Academy',
      "Women's Army Corps"
    ].freeze

    AIR_FORCE_EQUIVALENTS = [
      'Air Force Academy',
      'Air Force Reserves'
    ].freeze

    ARMY_EQUIVALENTS = [
      'Army Reserves',
      'Army Air Corps or Army Air Force',
      'Army Nurse Corps',
      'US Military Academy',
      "Women's Army Corps"
    ].freeze

    COAST_GUARD_EQUIVALENTS = [
      'Coast Guard Academy',
      'Coast Guard Reserves'
    ].freeze

    MARINE_EQUIVALENTS = [
      'Marine Corps',
      'Marine Corps Reserves',
      'Merchant Marine'
    ].freeze

    NAVY_EQUIVALENTS = [
      'Naval Academy',
      'Navy Reserves'
    ].freeze

    UNKNOWN_EQUIVALENTS = [
      'Other'
    ].freeze

    def initialize(service_branch)
      @service_branch = service_branch
    end

    def value
      return @service_branch unless OLD_VALUES.include?(@service_branch)

      return 'Air Force'    if AIR_FORCE_EQUIVALENTS.include?(@service_branch)
      return 'Army'         if ARMY_EQUIVALENTS.include?(@service_branch)
      return 'Coast Guard'  if COAST_GUARD_EQUIVALENTS.include?(@service_branch)
      return 'Marine'       if MARINE_EQUIVALENTS.include?(@service_branch)
      return 'Navy'         if NAVY_EQUIVALENTS.include?(@service_branch)
      return 'Unknown'      if UNKNOWN_EQUIVALENTS.include?(@service_branch)
    end
  end
end
