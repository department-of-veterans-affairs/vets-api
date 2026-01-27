# frozen_string_literal: true

module Burials
  module PdfFill
    # Constants used for PDF mapping
    module Constants
      # The Recipients Type
      RELATIONSHIPS = {
        'spouse' => 0,
        'child' => 1,
        'parent' => 2,
        'executor' => 3,
        'funeralDirector' => 4,
        'otherFamily' => 5
      }.freeze

      # Location of Death Types
      LOCATION_OF_DEATH = {
        'nursingHomeUnpaid' => 0,
        'nursingHomePaid' => 1,
        'vaMedicalCenter' => 2,
        'stateVeteransHome' => 3,
        'other' => 4
      }.freeze

      # Bank Account Types
      BANK_ACCOUNT_TYPES = {
        'checking' => 0,
        'savings' => 1,
        'noAccount' => 2
      }.freeze
    end
  end
end
