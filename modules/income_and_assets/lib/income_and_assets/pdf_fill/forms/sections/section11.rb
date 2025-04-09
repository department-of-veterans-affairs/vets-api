require 'pdf_fill/forms/form_helper'

module IncomeAndAssets
  module PdfFill::Forms
    class Section11
      extend ::PdfFill::Forms::FormHelper
      extend IncomeAndAssets::Helpers

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # Section configuration hash
      KEY = {
        # 11a
        'discontinuedIncome' => { key: 'F[0].#subform[9].DependentReceiveIncome11a[0]' },
        # 11b-11c (only space for 2 on form)
        'discontinuedIncomes' => {
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].RelationshipToVeteran11[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          # Q2
          'recipientName' => {
            key: "F[0].IncomeRecipientName11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, etc.)'
          },
          # Q4
          'incomeType' => {
            key: "F[0].TypeOfIncomeReceived11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(4)',
            question_text: 'SPECIFY TYPE OF INCOME RECEIVED (Interest, dividends, etc.)'
          },
          # Q5
          'incomeFrequency' => {
            key: "F[0].FrequencyOfIncomeReceived[#{ITERATOR}]"
          },
          'incomeFrequencyOverflow' => {
            question_num: 11,
            question_suffix: '(5)',
            question_text: 'SPECIFY FREQUENCY OF INCOME RECEIVED'
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
            question_text: 'DATE INCOME LAST PAID (MM/DD/YYYY)'
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
            question_text: 'WHAT WAS THE GROSS ANNUAL AMOUNT REPORTED TO THE IRS?'
          }
        }
      }

      def self.expand(form_data)
        incomes = form_data['discontinuedIncomes']

        form_data['discontinuedIncome'] = incomes&.length ? 0 : 1
        form_data['discontinuedIncomes'] = incomes&.map { |income| expand_item(income) }
      end

      def self.expand_item(item)
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
