# frozen_string_literal: true

module MedicalExpenseReports
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

    # The Income Types
    RECIPIENTS = {
      'VETERAN' => 4,
      'SPOUSE' => 1,
      'CHILD' => 3,
      'OTHER' => 2
    }.freeze

    # Frequency Types
    PAYMENT_FREQUENCY = {
      'ONCE_MONTH' => 4,
      'ONCE_YEAR' => 1,
      'ONE_TIME' => 3
    }.freeze
  end
end
