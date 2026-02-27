# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section09
  ##
  # Section IX
  # Build Income and Asset structured data entries.
  #
  # @param form [Hash]
  # @return [Hash]
  def merge_income_and_assets_info
    merge_income_fields(form['incomeEntries'])
    fields.merge!(y_n_pair(form['landMarketable'], 'MARKETABLE_LAND_2ACR_Y', 'MARKETABLE_LAND_2ACR_N'))
    fields.merge!(y_n_pair(form['transferredAssets'], 'TRANSFER_ASSETS_LAST3Y_Y', 'TRANSFER_ASSETS_LAST3Y_N'))
    fields.merge!(y_n_pair(form['homeOwnership'], 'OWN_PRIMARY_RESIDENCE_Y', 'OWN_PRIMARY_RESIDENCE_N'))
    fields.merge!(y_n_pair(form['homeAcreageMoreThanTwo'], 'RESLOT_OVER_2ACR_Y', 'RESLOT_OVER_2ACR_N'))
    fields.merge!(y_n_pair(form['moreThanFourIncomeSources'], 'MORETHAN4_INCSOURCE_Y', 'MORETHAN4_INCSOURCE_N'))
    fields.merge!(y_n_pair(form['otherIncome'], 'PREV_YEAR_OTHER_INCOME_YES', 'PREV_YEAR_OTHER_INCOME_NO'))
    fields.merge!(y_n_pair(form['totalNetWorth'], 'ASSETS_OVER_25K_Y', 'ASSETS_OVER_25K_N'))
    fields.merge!(
      {
        'AMNT_ESTIMATE_ASSETS' => format_currency(form['netWorthEstimation'] || 0),
        'AMNT_VALUE_OF_LOT' => format_currency(form['homeAcreageValue'] || 0)
      }
    )
  end

  ##
  # Build and merge the structured data fields for the claimant's income entries.
  #
  # @param incomes [Array<Hash>] An array of income entry hashes from the form
  # @param fields [Hash] The existing structured data fields to merge into (optional)
  def merge_income_fields(incomes)
    incomes&.each_with_index do |income, index|
      income_num = index + 1
      fields.merge!(build_currency_fields(income['monthlyIncome'], monthly_income_keys(income_num)))
      fields.merge!(
        {
          "CB_INC_RECIPIENT#{income_num}_SP" => income['recipient'] == 'SURVIVING_SPOUSE',
          "CB_INC_RECIPIENT#{income_num}_CHILD" => income['recipient'] == 'CHILD',
          "NAME_OF_CHILD_INCOMETYPE#{income_num}" => income['recipientName'] || '',
          "CB_INCOMETYPE#{income_num}_SS" => income['incomeType'] == 'SOCIAL_SECURITY',
          "CB_INCOMETYPE#{income_num}_PENSION" => income['incomeType'] == 'PENSION_RETIREMENT',
          "CB_INCOMETYPE#{income_num}_CIVIL" => income['incomeType'] == 'CIVIL_SERVICE',
          "CB_INCOMETYPE#{income_num}_INTEREST" => income['incomeType'] == 'INTEREST_DIVIDENDS',
          "CB_INCOMETYPE#{income_num}_OTHER" => income['incomeType'] == 'OTHER',
          "CB_INCOMETYPE#{income_num}_OTHERSPECIFY" => income['incomeTypeOther'] || '',
          "INCOME_PAYER_#{income_num}" => income['incomePayer'] || ''
        }
      )
    end
  end

  ##
  # Define the keys for the monthly income fields based on the income number.
  #
  # @param income_num [Integer] The number of the income entry (e.g., 1 for the first income, 2 for the second, etc.)
  # @return [Hash] A hash containing the keys for the monthly income fields
  def monthly_income_keys(income_num)
    {
      full: "MONTHLY_GROSS_#{income_num}",
      thousands: "MONTHLY_GROSS_#{income_num}_THSNDS",
      hundreds: "MONTHLY_GROSS_#{income_num}_HNDRDS",
      cents: "MONTHLY_GROSS_#{income_num}_CENTS"
    }
  end
end
