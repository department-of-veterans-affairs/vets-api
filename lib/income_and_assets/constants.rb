# frozen_string_literal: true

module IncomeAndAssets
  class Constants
    CLAIMANT_TYPES = {
      'VETERAN' => 0,
      'SPOUSE' => 1,
      'CHILD' => 2,
      'PARENT' => 3,
      'CUSTODIAN' => 4
    }.freeze

    RELATIONSHIPS = {
      'VETERAN' => 0,
      'SPOUSE' => 1,
      'CUSTODIAN' => 2,
      'CHILD' => 3,
      'PARENT' => 4,
      'OTHER' => 5
    }.freeze

    INCOME_TYPES = {
      'SOCIAL_SECURITY' => 0,
      'RETIREMENT_PENSION' => 1,
      'WAGES' => 2,
      'UNEMPLOYMENT' => 3,
      'CIVIL_SERVICE' => 4,
      'OTHER' => 5
    }.freeze

    ACCOUNT_INCOME_TYPES = {
      'INTEREST' => 0,
      'DIVIDENDS' => 1,
      'OTHER' => 2
    }.freeze

    ASSET_TYPES = {
      'FARM' => 0,
      'BUSINESS' => 1,
      'RENTAL_PROPERTY' => 2
    }.freeze

    TRANSFER_METHODS = {
      'SOLD' => 0,
      'GIFTED' => 1,
      'CONVEYED' => 2,
      'TRADED' => 3,
      'OTHER' => 4
    }.freeze
  end
end
