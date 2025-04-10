# frozen_string_literal: true

module IncomeAndAssets
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

    # Type of relationships
    RELATIONSHIPS = {
      'VETERAN' => 0,
      'SPOUSE' => 1,
      'CUSTODIAN' => 2,
      'CHILD' => 3,
      'PARENT' => 4,
      'OTHER' => 5
    }.freeze

    # Types of income
    INCOME_TYPES = {
      'SOCIAL_SECURITY' => 0,
      'RETIREMENT_PENSION' => 1,
      'WAGES' => 2,
      'UNEMPLOYMENT' => 3,
      'CIVIL_SERVICE' => 4,
      'OTHER' => 5
    }.freeze

    # Frequency of income
    INCOME_FREQUENCIES = {
      'RECURRING' => 0,
      'IRREGULAR' => 1,
      'ONE_TIME' => 2
    }.freeze

    # Types of account income
    ACCOUNT_INCOME_TYPES = {
      'INTEREST' => 0,
      'DIVIDENDS' => 1,
      'OTHER' => 2
    }.freeze

    # Types of assets
    ASSET_TYPES = {
      'FARM' => 0,
      'BUSINESS' => 1,
      'RENTAL_PROPERTY' => 2
    }.freeze

    # Types of transfer methods
    TRANSFER_METHODS = {
      'SOLD' => 0,
      'GIFTED' => 1,
      'CONVEYED' => 2,
      'TRADED' => 3,
      'OTHER' => 4
    }.freeze

    # Types of trust
    TRUST_TYPES = { 'REVOCABLE' => 0, 'IRREVOCABLE' => 1, 'BURIAL' => 2 }.freeze
  end
end
