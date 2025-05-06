# frozen_string_literal: true

module Pensions
  ##
  # Constants used for PDF mapping
  #
  module PdfFill
    module Constants
      # The Recipients Type
      RECIPIENTS = {
        'VETERAN' => 0,
        'SPOUSE' => 1,
        'DEPENDENT' => 2
      }.freeze

      # The Income Types
      INCOME_TYPES = {
        'SOCIAL_SECURITY' => 0,
        'INTEREST_DIVIDEND' => 1,
        'CIVIL_SERVICE' => 2,
        'PENSION_RETIREMENT' => 3,
        'OTHER' => 4
      }.freeze

      # Medical Care Types
      CARE_TYPES = {
        'CARE_FACILITY' => 0,
        'IN_HOME_CARE_PROVIDER' => 1
      }.freeze

      # The Payment Frequency
      PAYMENT_FREQUENCY = {
        'ONCE_MONTH' => 0,
        'ONCE_YEAR' => 1,
        'ONE_TIME' => 2
      }.freeze

      # The reason for marital separation
      REASONS_FOR_SEPARATION = {
        'DEATH' => 0,
        'DIVORCE' => 1,
        'OTHER' => 2
      }.freeze
    end
  end
end
