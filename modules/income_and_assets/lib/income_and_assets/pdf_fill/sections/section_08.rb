# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section VIII: Trusts
    class Section8 < Section
      # Section configuration hash
      KEY = {
        # 8a
        'trust' => { key: 'F[0].Page_10[0].DependentsEstablishedATrust[0]' },
        # 8b-8m (only space for one on form)
        'trusts' => {
          limit: 1,
          first_key: 'establishedDate', # No text fields in this section
          # 8b
          'establishedDate' => {
            'month' => { key: "F[0].Page_10[0].Month8b[#{ITERATOR}]" },
            'day' => { key: "F[0].Page_10[0].Day8b[#{ITERATOR}]" },
            'year' => { key: "F[0].Page_10[0].Year8b[#{ITERATOR}]" }
          },
          'establishedDateOverflow' => {
            question_num: 8,
            question_suffix: 'B',
            question_text: 'DATE TRUST ESTABLISHED (MM/DD/YYYY)'
          },
          # 8c
          'marketValueAtEstablishment' => {
            'millions' => { key: "F[0].Page_10[0].MarketValue1_8c[#{ITERATOR}]" },
            'thousands' => { key: "F[0].Page_10[0].MarketValue2_8c[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].MarketValue3_8c[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].MarketValue4_8c[#{ITERATOR}]" }
          },
          'marketValueAtEstablishmentOverflow' => {
            question_num: 8,
            question_suffix: 'C',
            question_text: 'SPECIFY MARKET VALUE OF ALL ASSETS WITHIN THE TRUST AT TIME OF ESTABLISHEMENT'
          },
          # 8d
          'trustType' => { key: "F[0].Page_10[0].TypeOfTrust8d[#{ITERATOR}]" },
          'trustTypeOverflow' => {
            question_num: 8,
            question_suffix: 'D',
            question_text: 'SPECIFY TYPE OF TRUST ESTABLISHED'
          },
          # 8e
          'addedFundsAfterEstablishment' => { key: "F[0].Page_10[0].AddedAdditionalFunds8e[#{ITERATOR}]" },
          'addedFundsAfterEstablishmentOverflow' => {
            question_num: 8,
            question_suffix: 'E',
            question_text: 'HAVE YOU ADDED FUNDS TO THE TRUST AFTER IT WAS ESTABLISHED?'
          },
          # 8f
          'addedFundsDate' => {
            'month' => { key: "F[0].Page_10[0].Transfer8fMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].Page_10[0].Transfer8fDay[#{ITERATOR}]" },
            'year' => { key: "F[0].Page_10[0].Transfer8fYear[#{ITERATOR}]" }
          },
          'addedFundsDateOverflow' => {
            question_num: 8,
            question_suffix: 'F',
            question_text: 'WHEN DID YOU ADD FUNDS? (MM/DD/YYYY)'
          },
          # 8g
          'addedFundsAmount' => {
            'thousands' => { key: "F[0].Page_10[0].HowMuchTransferred1_8g[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].HowMuchTransferred2_8g[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].HowMuchTransferred3_8g[#{ITERATOR}]" }
          },
          'addedFundsAmountOverflow' => {
            question_num: 8,
            question_suffix: 'G',
            question_text: 'HOW MUCH DID YOU ADD?'
          },
          # 8h
          'receivingIncomeFromTrust' => { key: "F[0].Page_10[0].ReceivingIncome8h[#{ITERATOR}]" },
          'receivingIncomeFromTrustOverflow' => {
            question_num: 8,
            question_suffix: 'H',
            question_text: 'ARE YOU RECEIVING INCOME FROM THE TRUST? '
          },
          # 8i
          'annualReceivedIncome' => {
            'thousands' => { key: "F[0].Page_10[0].ReceiveAnnually1_8i[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].ReceiveAnnually2_8i[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].ReceiveAnnually3_8i[#{ITERATOR}]" }
          },
          'annualReceivedIncomeOverflow' => {
            question_num: 8,
            question_suffix: 'I',
            question_text: 'HOW MUCH DO YOU RECEIVE ANNUALLY?'
          },
          # 8j
          'trustUsedForMedicalExpenses' => { key: "F[0].Page_10[0].TrustUsedToPay8j[#{ITERATOR}]" },
          'trustUsedForMedicalExpensesOverflow' => {
            question_num: 8,
            question_suffix: 'J',
            question_text:
                      'IS THE TRUST BEING USED TO PAY FOR OR TO REIMBURSE SOMEONE ELSE FOR YOUR MEDICAL EXPENSES?'
          },
          # 8k
          'monthlyMedicalReimbursementAmount' => {
            'thousands' => { key: "F[0].Page_10[0].ReimbursedMonthly1_8k[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].ReimbursedMonthly2_8k[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].ReimbursedMonthly3_8k[#{ITERATOR}]" }
          },
          'monthlyMedicalReimbursementAmountOverflow' => {
            question_num: 8,
            question_suffix: 'K',
            question_text: 'HOW MUCH IS BEING REIMBURSED MONTHLY?'
          },
          # 8l
          'trustEstablishedForVeteransChild' => { key: "F[0].Page_10[0].EstablishedForChild8l[#{ITERATOR}]" },
          'trustEstablishedForVeteransChildOverflow' => {
            question_num: 8,
            question_suffix: 'L',
            question_text: 'WAS THE TRUST ESTABLISHED FOR A CHILD OF THE VETERAN WHO WAS INCAPABLE OF SELF-SUPPORT PRIOR TO REACHING AGE 18?' # rubocop:disable Layout/LineLength
          },
          # 8m
          'haveAuthorityOrControlOfTrust' => { key: "F[0].Page_10[0].AdditionalAuthority8m[#{ITERATOR}]" },
          'haveAuthorityOrControlOfTrustOverflow' => {
            question_num: 8,
            question_suffix: 'M',
            question_text: 'DO YOU HAVE ANY ADDITIONAL AUTHORITY OR CONTROL OF THE TRUST?'
          }
        }
      }.freeze

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
