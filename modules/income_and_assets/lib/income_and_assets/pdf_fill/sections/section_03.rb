# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section III: Unassociated Incomes
    class Section3 < Section
      # Section configuration hash
      KEY = {
        # 3a
        'unassociatedIncome' => {
          key: 'F[0].Page_4[0].DependentsReceiving3a[0]'
        },
        # 3b - 3f (only space for five on form)
        'unassociatedIncomes' => {
          # Label for each income entry (e.g., 'Income 1')
          item_label: 'Income',
          limit: 5,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients3[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship'
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship Type'
          },
          # Q2
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Name'
          },
          # Q3
          'incomeType' => {
            key: "F[0].TypeOfIncome3[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Income Type'
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Other Income Type'
          },
          # Q4
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
            dollar: true,
            question_num: 3,
            question_suffix: '(4)',
            question_text: 'GROSS MONTHLY INCOME',
            question_label: 'Gross Monthly Income'
          },
          # Q5
          'payer' => {
            key: "F[0].IncomePayer3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(5)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)',
            question_label: 'Payer'
          }
        }
      }.freeze

      ##
      # Expands the unassociated incomes
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        incomes = form_data['unassociatedIncomes']
        form_data['unassociatedIncome'] = incomes&.length ? 0 : 1
        form_data['unassociatedIncomes'] = incomes&.map do |item|
          expand_item(item)
        end
      end

      ##
      # Expands unassociated income details by mapping relationships and income types
      # to their respective constants and formatting the gross monthly income.
      #
      # @param item [Hash] The income data to be processed.
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        income_type = item['incomeType']
        gross_monthly_income = item['grossMonthlyIncome']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => item['otherRecipientRelationshipType'],
          'recipientName' => item['recipientName'],
          'incomeType' => IncomeAndAssets::Constants::INCOME_TYPES[income_type],
          'incomeTypeOverflow' => income_type,
          'otherIncomeType' => item['otherIncomeType'],
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => gross_monthly_income,
          'payer' => item['payer']
        }
      end
    end
  end
end
