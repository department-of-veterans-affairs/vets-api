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

    # Relationship types
    RELATIONSHIPS = %w[
      SURVIVING_SPOUSE
      CHILD_18-23_IN_SCHOOL
      CUSTODIAN_FILING_FOR_CHILD_UNDER_18
      HELPLESS_ADULT_CHILD
    ].freeze

    # Recipient types
    RECIPIENTS = {
      'SURVIVING_SPOUSE' => 3,
      'VETERAN' => 1,
      'CHILD' => 2
    }.freeze

    # Frequencies
    FREQUENCIES = {
      'MONTHLY' => 1,
      'ANNUALLY' => 2,
      'ONE_TIME' => 3
    }.freeze
  end
end
