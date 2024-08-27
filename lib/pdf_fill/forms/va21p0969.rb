# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/hash_converter'

module PdfFill
  module Forms
    class Va21p0969 < FormBase
      include ActiveSupport::NumberHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      RECIPIENTS = {
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

      KEY = {
        # 3a
        'unassociatedIncome' => {
          key: 'F[0].Page_4[0].DependentsReceiving3a[0]'
        },
        # 3b - 3f
        'unassociatedIncomes' => {
          limit: 5,
          first_key: 'recipientRelationship',
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients3[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          'incomeType' => {
            key: "F[0].TypeOfIncome3[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
          'grossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].GrossMonthlyIncome1_3[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossMonthlyIncome2_3[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossMonthlyIncome3_3[#{ITERATOR}]"
            }
          },
          'grossMonthlyIncomeOverflow' => {
            question_num: 3,
            question_suffix: '(4)',
            question_text: 'GROSS MONTHLY INCOME'
          },
          'payer' => {
            key: "F[0].IncomePayer3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(5)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        expand_unassociated_incomes

        form_data
      end

      private

      def expand_unassociated_incomes
        unassociated_incomes = form_data['unassociatedIncomes']
        form_data['unassociatedIncome'] = unassociated_incomes&.length ? 'YES' : 1
        form_data['unassociatedIncomes'] = unassociated_incomes&.map do |income|
          expand_unassociated_income(income)
        end
      end

      # :reek:FeatureEnvy
      def expand_unassociated_income(income)
        recipient_relationship = income['recipientRelationship']
        income_type = income['incomeType']
        gross_monthly_income = income['grossMonthlyIncome']
        {
          'recipientRelationship' => RECIPIENTS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => income['otherRecipientRelationshipType'],
          'recipientName' => income['recipientName'],
          'incomeType' => INCOME_TYPES[income_type],
          'incomeTypeOverflow' => income_type,
          'otherIncomeType' => income['otherIncomeType'],
          'grossMonthlyIncome' => gross_monthly_income ? split_currency_amount(gross_monthly_income) : {},
          'grossMonthlyIncomeOverflow' => gross_monthly_income,
          'payer' => income['payer']
        }
      end

      def split_currency_amount(amount)
        return {} if amount.negative? || amount >= 100_000

        arr = number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
        {
          'cents' => get_currency_field(arr, -1, 2),
          'dollars' => get_currency_field(arr, -2, 3),
          'thousands' => get_currency_field(arr, -3, 2)
        }
      end

      # :reek:FeatureEnvy
      def get_currency_field(arr, neg_i, field_length)
        value = arr.length >= -neg_i ? arr[neg_i] : 0
        format("%0#{field_length}d", value.to_i)
      end
    end
  end
end
