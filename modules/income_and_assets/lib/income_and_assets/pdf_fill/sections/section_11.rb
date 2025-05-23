# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section XI: Discontinued Incomes
    class Section11 < Section
      # Section configuration hash
      KEY = {
        # 11a
        'discontinuedIncome' => { key: 'F[0].#subform[9].DependentReceiveIncome11a[0]' },
        # 11b-11c (only space for 2 on form)
        'discontinuedIncomes' => {
          # Label for each discontinued income entry (e.g., 'Discontinued Income 1')
          item_label: 'Discontinued Income',
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].RelationshipToVeteran11[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Recipient Relationship'
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN (OTHER)",
            question_label: 'Other Relationship'
          },
          # Q2
          'recipientName' => {
            key: "F[0].IncomeRecipientName11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Recipient Name'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, etc.)',
            question_label: 'Income Payer'
          },
          # Q4
          'incomeType' => {
            key: "F[0].TypeOfIncomeReceived11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(4)',
            question_text: 'SPECIFY TYPE OF INCOME RECEIVED (Interest, dividends, etc.)',
            question_label: 'Income Type'
          },
          # Q5
          'incomeFrequency' => {
            key: "F[0].FrequencyOfIncomeReceived[#{ITERATOR}]"
          },
          'incomeFrequencyOverflow' => {
            question_num: 11,
            question_suffix: '(5)',
            question_text: 'SPECIFY FREQUENCY OF INCOME RECEIVED',
            question_label: 'Income Frequency'
          },
          # Q6
          'incomeLastReceivedDate' => {
            'month' => { key: "F[0].DateIncomeLastPaidMonth11[#{ITERATOR}]" },
            'day' => { key: "F[0].DateIncomeLastPaidDay11[#{ITERATOR}]" },
            'year' => { key: "F[0].DateIncomeLastPaidYear11[#{ITERATOR}]" }
          },
          'incomeLastReceivedDateOverflow' => {
            question_num: 11,
            question_suffix: '(6)',
            question_text: 'DATE INCOME LAST PAID (MM/DD/YYYY)',
            question_label: 'Date Income Last Paid'
          },
          # Q7
          'grossAnnualAmount' => {
            'thousands' => {
              key: "F[0].GrossAnnualAmount1_11[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossAnnualAmount2_11[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossAnnualAmount3_11[#{ITERATOR}]"
            }
          },
          'grossAnnualAmountOverflow' => {
            question_num: 11,
            question_suffix: '(7)',
            question_text: 'WHAT WAS THE GROSS ANNUAL AMOUNT REPORTED TO THE IRS?',
            question_label: 'Gross Annual Amount'
          }
        }
      }.freeze

      ##
      # Expands discontinued incomes by processing each discontinued income entry and setting an indicator
      # based on the presence of discontinued incomes.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        incomes = form_data['discontinuedIncomes']

        form_data['discontinuedIncome'] = incomes&.length ? 0 : 1
        form_data['discontinuedIncomes'] = incomes&.map { |income| expand_item(income) }
      end

      ##
      # Expands a discontinued incomes's data by processing its attributes and transforming them into
      # structured output
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        income_frequency = item['incomeFrequency']
        income_last_received_date = item['incomeLastReceivedDate']

        # NOTE: recipientName, payer, and incomeType are already part of the income hash
        # and do not need to be overflowed / overriden as they are free text fields
        overflow_fields = %w[recipientRelationship incomeFrequency grossAnnualAmount]

        expanded = item.clone
        overflow_fields.each do |field|
          expanded["#{field}Overflow"] = item[field]
        end

        overrides = {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'incomeFrequency' => IncomeAndAssets::Constants::INCOME_FREQUENCIES[income_frequency],
          'incomeLastReceivedDate' => split_date(income_last_received_date),
          'incomeLastReceivedDateOverflow' => format_date_to_mm_dd_yyyy(income_last_received_date),
          'grossAnnualAmount' => split_currency_amount_sm(item['grossAnnualAmount'])
        }

        expanded.merge(overrides)
      end
    end
  end
end
