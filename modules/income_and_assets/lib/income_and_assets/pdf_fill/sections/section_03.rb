# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section III: Unassociated Incomes
    class Section3 < Section
      # Section configuration hash
      #
      # NOTE: `key` fields should follow the format:
      #   `<key_prefix><subprefix>.<key>`
      # Example: 'Section3A.DependentsReceivingIncome'
      #
      KEY = {
        # 3A
        'unassociatedIncome' => {
          key: generate_key('3A', 'DependentsReceivingIncome')
        },
        # 3B-F (only space for five on form)
        'unassociatedIncomes' => {
          # Label for each income entry (e.g., 'Income 1')
          item_label: 'Income',
          limit: 5,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: generate_key('3B-F(1)', "IncomeRecipient.Relationship[#{ITERATOR}]")
          },
          'recipientRelationshipOverflow' => {
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship'
          },
          'otherRecipientRelationshipType' => {
            key: generate_key('3B-F(1)', "IncomeRecipient.RelationshipOther[#{ITERATOR}]"),
            question_num: 3,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship Type'
          },
          # Q2
          'recipientName' => {
            key: generate_key('3B-F(2)', "IncomeRecipient.Name[#{ITERATOR}]"),
            question_num: 3,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Name'
          },
          # Q3
          'incomeType' => {
            key: generate_key('3B-F(3)', "IncomeType[#{ITERATOR}]")
          },
          'incomeTypeOverflow' => {
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Income Type'
          },
          'otherIncomeType' => {
            key: generate_key('3B-F(3)', "IncomeTypeOther[#{ITERATOR}]"),
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Other Income Type'
          },
          # Q4
          'grossMonthlyIncome' => {
            'thousands' => {
              key: generate_key('3B-F(4)', "GrossMonthlyIncome1[#{ITERATOR}]")
            },
            'dollars' => {
              key: generate_key('3B-F(4)', "GrossMonthlyIncome2[#{ITERATOR}]")
            },
            'cents' => {
              key: generate_key('3B-F(4)', "GrossMonthlyIncome3[#{ITERATOR}]")
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
            key: generate_key('3B-F(5)', "IncomePayer[#{ITERATOR}]"),
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
