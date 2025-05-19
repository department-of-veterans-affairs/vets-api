# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section IX: Annuities
    class Section9 < Section
      # Section configuration hash
      KEY = {
        # 9a
        'annuity' => { key: 'F[0].#subform[8].DependentsEstablishedAnnuity9a[0]' },
        # 9b-9k (only space for one on form)
        'annuities' => {
          # Label for each annuity entry (e.g., 'Annuity 1')
          item_label: 'Annuity',
          limit: 1,
          first_key: 'establishedDate', # No text fields in this section
          # 9b
          'establishedDate' => {
            'month' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedDay[#{ITERATOR}]" },
            'year' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedYear[#{ITERATOR}]" }
          },
          'establishedDateOverflow' => {
            question_num: 9,
            question_suffix: 'B',
            question_text: 'SPECIFY DATE ANNUITY WAS ESTABLISHED',
            question_label: 'Date Established'
          },
          # 9c
          'marketValueAtEstablishment' => {
            'millions' => { key: "F[0].#subform[8].MarketAnnuity1_9c[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].MarketAnnuity2_9c[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].MarketAnnuity3_9c[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].MarketAnnuity4_9c[#{ITERATOR}]" }
          },
          'marketValueAtEstablishmentOverflow' => {
            question_num: 9,
            question_suffix: 'C',
            question_text: 'SPECIFY MARKET VALUE OF ASSET AT TIME OF ANNUITY PURCHASE',
            question_label: 'Market Value'
          },
          # 9d
          'addedFundsAfterEstablishment' => { key: 'F[0].#subform[8].AddedFundsToAnnuity9d[0]' },
          'addedFundsAfterEstablishmentOverflow' => {
            question_num: 9,
            question_suffix: 'D',
            question_text: 'HAVE YOU ADDED FUNDS TO THE ANNUITY IN THE CURRENT OR PRIOR THREE YEARS?',
            question_label: 'Added Funds'
          },
          # 9e
          'addedFundsDate' => {
            'month' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredDay[#{ITERATOR}]" },
            'year' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredYear[#{ITERATOR}]" }
          },
          'addedFundsDateOverflow' => {
            question_num: 9,
            question_suffix: 'E',
            question_text: 'WHEN DID YOU ADD FUNDS?',
            question_label: 'Date Added'
          },
          # 9f
          'addedFundsAmount' => {
            'millions' => { key: "F[0].#subform[8].HowMuchTransferred1_9f[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].HowMuchTransferred2_9f[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].HowMuchTransferred3_9f[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].HowMuchTransferred4_9f[#{ITERATOR}]" }
          },
          'addedFundsAmountOverflow' => {
            question_num: 9,
            question_suffix: 'F',
            question_text: 'HOW MUCH DID YOU ADD?',
            question_label: 'Amount Added'
          },
          # 9g
          'revocable' => { key: "F[0].#subform[8].Annuity9g[#{ITERATOR}]" },
          'revocableOverflow' => {
            question_num: 9,
            question_suffix: 'G',
            question_text: 'IS THE ANNUITY REVOCABLE OR IRREVOCABLE?',
            question_label: 'Revocable or Irrevocable'
          },
          # 9h
          'receivingIncomeFromAnnuity' => { key: "F[0].#subform[8].ReceiveIncomeFromAnnuity9h[#{ITERATOR}]" },
          'receivingIncomeFromAnnuityOverflow' => {
            question_num: 9,
            question_suffix: 'H',
            question_text: 'DO YOU RECEIVE INCOME FROM THE ANNUNITY?',
            question_label: 'Receiving Income from Annuity'
          },
          # 9i
          'annualReceivedIncome' => {
            'millions' => { key: "F[0].#subform[8].AnnualAmountReceived1_9i[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].AnnualAmountReceived2_9i[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].AnnualAmountReceived3_9i[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].AnnualAmountReceived4_9i[#{ITERATOR}]" }
          },
          'annualReceivedIncomeOverflow' => {
            question_num: 9,
            question_suffix: 'I',
            question_text: 'IF YES IN 9H, PROVIDE ANNUAL AMOUNT RECEIVED',
            question_label: 'Annual Received Income'
          },
          # 9j
          'canBeLiquidated' => { key: "F[0].#subform[8].AnnuityLiquidated9j[#{ITERATOR}]" },
          'canBeLiquidatedOverflow' => {
            question_num: 9,
            question_suffix: 'J',
            question_text: 'CAN THE ANNUITY BE LIQUIDATED?',
            question_label: 'Can Be Liquidated'
          },
          # 9k
          'surrenderValue' => {
            'millions' => { key: "F[0].#subform[8].SurrenderValue1_9k[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].SurrenderValue2_9k[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].SurrenderValue3_9k[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].SurrenderValue4_9k[#{ITERATOR}]" }
          },
          'surrenderValueOverflow' => {
            question_num: 9,
            question_suffix: 'K',
            question_text: 'IF YES IN 9J, PROVIDE THE SURRENDER VALUE',
            question_label: 'Surrender Value'
          }
        }
      }.freeze

      ##
      # Expands annuities by processing each annuity entry and setting an indicator
      # based on the presence of annuities.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        annuities = form_data['annuities']
        form_data['annuity'] = annuities&.length ? 0 : 1
        form_data['annuities'] = annuities&.map { |item| expand_item(item) }
      end

      ##
      # Expands an annuity's data by processing its attributes and transforming them
      # into structured output
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        market_value = split_currency_amount_lg(item['marketValueAtEstablishment'], { 'millions' => 1 })
        expanded = {
          'addedFundsDate' => split_date(item['addedFundsDate']),
          'addedFundsAmount' => split_currency_amount_lg(item['addedFundsAmount'], { 'millions' => 1 }),
          'addedFundsAfterEstablishment' => item['addedFundsAfterEstablishment'] ? 0 : 1,
          'canBeLiquidated' => item['canBeLiquidated'] ? 0 : 1,
          'surrenderValue' => split_currency_amount_lg(item['surrenderValue'], { 'millions' => 1 }),
          'receivingIncomeFromAnnuity' => item['receivingIncomeFromAnnuity'] ? 0 : 1,
          'annualReceivedIncome' => split_currency_amount_lg(item['annualReceivedIncome'], { 'millions' => 1 }),
          'revocable' => item['revocable'] ? 0 : 1,
          'establishedDate' => split_date(item['establishedDate']),
          'marketValueAtEstablishment' => market_value
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
