# frozen_string_literal: true

module MedicalCopays
  module CernerFacilities
    # These are parent facility station IDs for facilites that are
    # scheduled to migrate to cerner between now and July 2027
    FUTURE_CERNER_FACILITY_IDS = %w[
      553
      655
      506
      515
      552
      538
      539
      583
      610
      541
      463
      676
      607
      585
      695
      550
      537
      578
      656
      438
      437
      618
      636
      568
    ].freeze

    def self.cerner_copay_user?(user)
      return true if user.cerner_facility_ids&.any?

      user_facility_ids = user.vha_facility_ids
      user_facility_ids.any? { |id| FUTURE_CERNER_FACILITY_IDS.include?(id) }
    end
  end
end
