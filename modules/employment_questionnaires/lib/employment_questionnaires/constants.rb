# frozen_string_literal: true

module EmploymentQuestionnaires
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

    # Converts number to word
    NUMBER_TO_WORDS = {
      '1' => 'One',
      '2' => 'Two',
      '3' => 'Three',
      '4' => 'Four',
      '5' => 'Five'
    }.freeze
  end
end
