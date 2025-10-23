# frozen_string_literal: true

module MedicalExpenseReports
  ##
  # Constants used for PDF mapping
  #
  class Constants
    # The Income Types
    RECIPIENTS = {
      'VETERAN' => 4,
      'SPOUSE' => 1,
      'DEPENDENT' => 3,
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
