# frozen_string_literal: true

module SurvivorsBenefits
  ##
  # Constants used for PDF mapping
  #
  class Constants
    # Types for Claimants
    CLAIMANT_TYPES = {
      'VETERAN' => 0,
      'SPOUSE' => 1,
      'CHILD' => 2,
      'PARENT' => 3,
      'CUSTODIAN' => 4
    }.freeze

    # The reason for marital separation
      REASONS_FOR_SEPARATION = {
        'DEATH' => 1,
        'DIVORCE' => 2,
        'OTHER' => 4
      }.freeze
  end
end
