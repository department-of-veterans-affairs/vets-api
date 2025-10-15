# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section IX: Income And Assets (current income entries)
    class Section9 < Section
      include ::PdfFill::Forms::FormHelper
      include Helpers

      INCOME_RECIPIENT_FIELDS = [
        "form1[0].#subform[215].RadioButtonList[38]",
        "form1[0].#subform[215].RadioButtonList[40]",
        "form1[0].#subform[215].RadioButtonList[42]",
        "form1[0].#subform[215].RadioButtonList[44]"
      ].freeze

      INCOME_TYPE_FIELDS = [
        "form1[0].#subform[215].RadioButtonList[39]",
        "form1[0].#subform[215].RadioButtonList[41]",
        "form1[0].#subform[215].RadioButtonList[43]",
        "form1[0].#subform[215].RadioButtonList[45]"
      ].freeze

      INCOME_CHILD_NAME_FIELDS = [
        "form1[0].#subform[215].Name_Of_Child[0]",
        "form1[0].#subform[215].Name_Of_Child[1]",
        "form1[0].#subform[215].Name_Of_Child[2]",
        "form1[0].#subform[215].Name_Of_Child[3]"
      ].freeze

      INCOME_OTHER_TYPE_FIELDS = [
        "form1[0].#subform[215].Specify_Type_Of_Income[3]",
        "form1[0].#subform[215].Specify_Type_Of_Income[0]",
        "form1[0].#subform[215].Specify_Type_Of_Income[1]",
        "form1[0].#subform[215].Specify_Type_Of_Income[2]"
      ].freeze

      INCOME_PAYER_FIELDS = [
        "form1[0].#subform[215].Income_Payer[0]",
        "form1[0].#subform[215].Income_Payer[1]",
        "form1[0].#subform[215].Income_Payer[2]",
        "form1[0].#subform[215].Income_Payer[3]"
      ].freeze

      INCOME_AMOUNT_THOUSANDS_FIELDS = [
        "form1[0].#subform[215].Monthly_Amount[0]",
        "form1[0].#subform[215].Monthly_Amount[3]",
        "form1[0].#subform[215].Monthly_Amount[6]",
        "form1[0].#subform[215].Monthly_Amount[9]"
      ].freeze

      INCOME_AMOUNT_DOLLARS_FIELDS = [
        "form1[0].#subform[215].Monthly_Amount[1]",
        "form1[0].#subform[215].Monthly_Amount[4]",
        "form1[0].#subform[215].Monthly_Amount[7]",
        "form1[0].#subform[215].Monthly_Amount[10]"
      ].freeze

      INCOME_AMOUNT_CENTS_FIELDS = [
        "form1[0].#subform[215].Monthly_Amount[2]",
        "form1[0].#subform[215].Monthly_Amount[5]",
        "form1[0].#subform[215].Monthly_Amount[8]",
        "form1[0].#subform[215].Monthly_Amount[11]"
      ].freeze

      INCOME_ENTRY_COUNT = INCOME_RECIPIENT_FIELDS.length

      RECIPIENT_VALUES = {
        'SURVIVING_SPOUSE' => '0',
        'SPOUSE' => '0',
        'CHILD' => '1',
        'OTHER' => '2'
      }.freeze

      INCOME_TYPE_VALUES = {
        'SOCIAL_SECURITY' => '0',
        'INTEREST_DIVIDENDS' => '1',
        'CIVIL_SERVICE' => '2',
        'PENSION_RETIREMENT' => '3',
        'OTHER' => '4'
      }.freeze

      # --- Asset questions ---
      KEY = {
        'totalNetWorth' => { key: "form1[0].#subform[211].RadioButtonList[24]" },
        'netWorthEstimation' => {
          'thousands' => { key: 'form1[0].#subform[211].Amount[0]' },
          'dollars' => { key: 'form1[0].#subform[211].Amount[1]' },
          'cents' => { key: 'form1[0].#subform[211].Amount[2]' }
        },
        'transferredAssets' => { key: "form1[0].#subform[211].RadioButtonList[25]" },
        'homeOwnership' => { key: "form1[0].#subform[211].RadioButtonList[26]" },
        'homeAcreageMoreThanTwo' => { key: "form1[0].#subform[211].RadioButtonList[27]" },
        'homeAcreageValue' => {
          'millions' => { key: 'form1[0].#subform[211].Total_Annual_Earnings_Amount[5]' },
          'thousands' => { key: 'form1[0].#subform[211].Total_Annual_Earnings_Amount[6]' },
          'dollars' => { key: 'form1[0].#subform[211].Total_Annual_Earnings_Amount[4]' }
        },
        'landMarketable' => { key: "form1[0].#subform[211].RadioButtonList[28]" },
        'moreThanFourIncomeSources' => { key: "form1[0].#subform[211].RadioButtonList[29]" },
        'incomeEntries' => {
          limit: INCOME_ENTRY_COUNT,
          first_key: 'recipient',
          'recipient' => {
            key_from_iterator: ->(iterator) { INCOME_RECIPIENT_FIELDS[iterator] }
          },
          'childName' => {
            key_from_iterator: ->(iterator) { INCOME_CHILD_NAME_FIELDS[iterator] }
          },
          'incomeType' => {
            key_from_iterator: ->(iterator) { INCOME_TYPE_FIELDS[iterator] }
          },
          'incomeTypeOther' => {
            key_from_iterator: ->(iterator) { INCOME_OTHER_TYPE_FIELDS[iterator] }
          },
          'incomePayer' => {
            key_from_iterator: ->(iterator) { INCOME_PAYER_FIELDS[iterator] }
          },
          'monthlyIncome' => {
            'thousands' => {
              key_from_iterator: ->(iterator) { INCOME_AMOUNT_THOUSANDS_FIELDS[iterator] }
            },
            'dollars' => {
              key_from_iterator: ->(iterator) { INCOME_AMOUNT_DOLLARS_FIELDS[iterator] }
            },
            'cents' => {
              key_from_iterator: ->(iterator) { INCOME_AMOUNT_CENTS_FIELDS[iterator] }
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        # --- Expand asset answers ---
        form_data['totalNetWorth'] = yes_no_radio(form_data['totalNetWorth'])
        form_data['netWorthEstimation'] = normalize_small_currency(form_data['netWorthEstimation'])
        form_data['transferredAssets'] = yes_no_radio(form_data['transferredAssets'])
        form_data['homeOwnership'] = yes_no_radio(form_data['homeOwnership'])
        form_data['homeAcreageMoreThanTwo'] = yes_no_radio(form_data['homeAcreageMoreThanTwo'])
        form_data['homeAcreageValue'] = normalize_large_currency(form_data['homeAcreageValue'])
        form_data['landMarketable'] = yes_no_radio(form_data['landMarketable'])

        # --- Expand income entries ---
        entries = Array(form_data['incomeEntries'])

        form_data['incomeEntries'] = INCOME_ENTRY_COUNT.times.map do |index|
          entry = entries[index]
          entry.present? ? transform_income_entry(entry) : empty_income_entry
        end

        more_than_four = form_data['moreThanFourIncomeSources']
        more_than_four = entries.length > INCOME_ENTRY_COUNT if more_than_four.nil?
        form_data['moreThanFourIncomeSources'] = yes_no_radio(more_than_four)

        form_data
      end

      private

      def transform_income_entry(entry)
        data = {}

        recipient_value = normalize_enum(entry['recipient'] || entry['receiver'])
        data['recipient'] = RECIPIENT_VALUES[recipient_value] || 'Off'
        data['childName'] = recipient_value == 'CHILD' ? entry['childName'] || entry['dependentName'] : nil

        income_type_value = normalize_enum(entry['incomeType'] || entry['typeOfIncome'])
        data['incomeType'] = INCOME_TYPE_VALUES[income_type_value] || 'Off'
        data['incomeTypeOther'] = income_type_value == 'OTHER' ?
          (entry['incomeTypeOther'] || entry['otherTypeExplanation']) : nil

        data['incomePayer'] = entry['incomePayer'] || entry['payer']

        amount_value = entry['monthlyIncome'] || entry['amount']
        amount_parts = coerce_small_currency_hash(amount_value)
        data['monthlyIncome'] = normalize_small_amount_fields(amount_parts)

        data
      end

      # --- Helpers shared across asset & income sections ---
      def normalize_small_currency(value)
        amount_hash = coerce_small_currency_hash(value)
        normalize_small_amount_fields(amount_hash)
      end

      def normalize_small_amount_fields(amount_hash)
        return default_small_amount_fields if amount_hash.blank?

        normalized = {}
        %w[thousands dollars].each do |part|
          value = amount_hash[part]
          normalized[part] = value.present? ? value.to_s.strip.rjust(3, ' ') : '   '
        end
        normalized['cents'] = amount_hash['cents'].present? ? amount_hash['cents'].to_s.strip.rjust(2, '0') : '  '

        normalized
      end

      def normalize_large_currency(value)
        amount_hash = coerce_large_currency_hash(value)
        return default_large_amount_fields if amount_hash.blank?

        {
          'millions' => format_amount_part(amount_hash['millions'], 1),
          'thousands' => format_amount_part(amount_hash['thousands'], 3),
          'dollars' => format_amount_part(amount_hash['dollars'], 3)
        }
      end

      def coerce_small_currency_hash(value)
        return value if value.is_a?(Hash)
        return {} if value.blank?

        split_currency_amount_sm(value, { 'thousands' => 3 })
      end

      def coerce_large_currency_hash(value)
        return value if value.is_a?(Hash)
        return {} if value.blank?

        split_currency_amount_lg(value, { 'millions' => 1, 'thousands' => 3, 'dollars' => 3, 'cents' => 2 })
      end

      def format_amount_part(value, length)
        value.present? ? value.to_s.strip.rjust(length, ' ') : ' ' * length
      end

      def default_small_amount_fields
        { 'thousands' => '   ', 'dollars' => '   ', 'cents' => '  ' }
      end

      def default_large_amount_fields
        { 'millions' => ' ', 'thousands' => '   ', 'dollars' => '   ' }
      end

      def yes_no_radio(value)
        case value
        when true, 1, '1', 'YES', 'TRUE', 'Y' then '0'
        when false, 0, '0', 'NO', 'FALSE', 'N' then '1'
        else 'Off'
        end
      end

      def normalize_enum(value)
        value.to_s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/^_+|_+$/, '')
      end

      def empty_income_entry
        {
          'recipient' => 'Off',
          'childName' => nil,
          'incomeType' => 'Off',
          'incomeTypeOther' => nil,
          'incomePayer' => nil,
          'monthlyIncome' => default_small_amount_fields
        }
      end
    end
  end
end
