# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section VIII: Trusts
    class Section8 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expands trusts by processing each trust entry and setting an indicator
      # based on the presence of trusts.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        trusts = form_data['trusts']
        form_data['trust'] = trusts&.length ? 0 : 1
        form_data['trusts'] = trusts&.map { |item| expand_item(item) }
      end

      ##
      # Expands a trust's data by processing its attributes and transforming them
      # into structured output
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        market_value = split_currency_amount_lg(item['marketValueAtEstablishment'], { 'millions' => 1 })
        expanded = {
          'establishedDate' => split_date(item['establishedDate']),
          'marketValueAtEstablishment' => market_value,
          'trustType' => IncomeAndAssets::Constants::TRUST_TYPES[item['trustType']],
          'addedFundsAfterEstablishment' => item['addedFundsAfterEstablishment'] ? 0 : 1,
          'addedFundsDate' => split_date(item['addedFundsDate']),
          'addedFundsAmount' => split_currency_amount_sm(item['addedFundsAmount']),
          'receivingIncomeFromTrust' => item['receivingIncomeFromTrust'] ? 0 : 1,
          'annualReceivedIncome' => split_currency_amount_sm(item['annualReceivedIncome']),
          'trustUsedForMedicalExpenses' => item['trustUsedForMedicalExpenses'] ? 0 : 1,
          'monthlyMedicalReimbursementAmount' => split_currency_amount_sm(item['monthlyMedicalReimbursementAmount']),
          'trustEstablishedForVeteransChild' => item['trustEstablishedForVeteransChild'] ? 0 : 1,
          'haveAuthorityOrControlOfTrust' => item['haveAuthorityOrControlOfTrust'] ? 0 : 1
        }

        overflow = {}
        expanded.each_key do |fieldname|
          overflow["#{fieldname}Overflow"] = item[fieldname]
        end

        expanded.merge(overflow)
      end
    end
  end
end
