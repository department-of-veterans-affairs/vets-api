# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

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
        'OTHER' => 5,
      }.freeze

      INCOME_TYPES = {
        'SOCIAL_SECURITY' => 0,
        'RETIREMENT_PENSION' => 1,
        'WAGES' => 2,
        'UNEMPLOYMENT' => 3,
        'CIVIL_SERVICE' => 4,
        'OTHER' => 5,
    }.freeze

      KEY = {
        #3a
        'unassociatedIncome' => {
          key: 'F[0].Page_4[0].DependentsReceiving3a[0]'
        },
        #3b - 3f
        'unassociatedIncomes' => {
          limit: 5,
          first_key: 'recipientRelationship',
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients3[#{ITERATOR}]",
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
            question_text: "SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)"
          },
          'incomeType' => {
            key: "F[0].TypeOfIncome3[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 3,
            question_suffix: '(3)',
            question_text: "SPECIFY THE TYPE OF INCOME"
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(3)',
            question_text: "SPECIFY THE TYPE OF INCOME"
          },
          'grossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].GrossMonthlyIncome1_3[#{ITERATOR}]",
            },
            'dollars' => {
              key: "F[0].GrossMonthlyIncome2_3[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossMonthlyIncome3_3[#{ITERATOR}]"
            },
          },
          'grossMonthlyIncomeOverflow' => {
            question_num: 3,
            question_suffix: '(4)',
            question_text: "GROSS MONTHLY INCOME"
          },
          'payer' => {
              key: "F[0].IncomePayer3[#{ITERATOR}]",
              question_num: 3,
              question_suffix: '(5)',
              question_text: "SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)"
          }
        }
      }.freeze

      def merge_fields(_options = {})
        expand_unassociated_incomes

        @form_data
      end

      def expand_unassociated_incomes
        @form_data['unassociatedIncome'] = to_radio_yes_no(@form_data['unassociatedIncomes']&.length)
        @form_data['unassociatedIncomes'] = @form_data['unassociatedIncomes']&.map do |income|
          {
            'recipientRelationship' => RECIPIENTS[income['recipientRelationship']],
            'recipientRelationshipOverflow' => income['recipientRelationship'],
            'otherRecipientRelationshipType' => income['otherRecipientRelationshipType'],
            'recipientName' => income['recipientName'],
            'incomeType' => INCOME_TYPES[income['incomeType']],
            'incomeTypeOverflow' => income['incomeType'],
            'otherIncomeType' => income['otherIncomeType'],
            'grossMonthlyIncome' => split_currency_amount(income['grossMonthlyIncome']),
            'grossMonthlyIncomeOverflow' => income['grossMonthlyIncome'],
            'payer' => income['payer'],
          }
        end
      end

      # UTILITIES
      def to_radio_yes_no(obj)
        obj ? 'YES' : 1
      end

      def split_currency_amount(amount)
        return {} if amount.nil? || amount.negative? || amount >= 100_000

        arr = number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
        cents =  arr.length >= 1 ? arr[-1] : 0
        dollars =  arr.length >= 2? arr[-2] : 0
        thousands =  arr.length >= 3 ? arr[-3] : 0
        {
          'cents' => sprintf('%02d', cents.to_i),
          'dollars' => sprintf('%03d', dollars.to_i),
          'thousands' => sprintf('%02d', thousands.to_i)
        }
      end
    end
  end
end
