# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section IV: Associated Incomes
    class Section4 < Section
      # Section configuration hash
      KEY = {
        # 4a
        'associatedIncome' => {
          key: 'F[0].Page_6[0].DependentsReceiving4a[0]'
        },
        # 4b - 4f (only space for five on form)
        'associatedIncomes' => {
          # Label for each income entry (e.g., 'Income 1')
          item_label: 'Income',
          limit: 5,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients4[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 4,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship to Veteran',
            format_options: {
              humanize: true
            }
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship4[#{ITERATOR}]",
            limit: 22,
            question_num: 4,
            question_suffix: '(1)(OTHER)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship Type'
          },
          # Q2
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient4[#{ITERATOR}]",
            limit: 46,
            question_num: 4,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Name'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer4[#{ITERATOR}]",
            limit: 46,
            question_num: 4,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)',
            question_label: 'Payer'
          },
          # Q4
          'incomeType' => {
            key: "F[0].TypeOfIncome4[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 4,
            question_suffix: '(4)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Income Type',
            format_options: {
              humanize: true
            }
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType4[#{ITERATOR}]",
            limit: 25,
            question_num: 4,
            question_suffix: '(4)(OTHER)',
            question_text: 'SPECIFY THE TYPE OF INCOME',
            question_label: 'Other Income Type'
          },
          # Q5
          'grossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].GrossMonthlyIncome1_4[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossMonthlyIncome2_4[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossMonthlyIncome3_4[#{ITERATOR}]"
            }
          },
          'grossMonthlyIncomeOverflow' => {
            key: "grossMonthlyIncomeOverflow[#{ITERATOR}]", # Fake key for overflow handling
            limit: 10,
            dollar: true,
            question_num: 4,
            question_suffix: '(5)',
            question_text: 'GROSS MONTHLY INCOME',
            question_label: 'Gross Monthly Income'
          },
          # Q6
          'accountValue' => {
            'millions' => {
              key: "F[0].ValueOfAccount1_4[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].ValueOfAccount2_4[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].ValueOfAccount3_4[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].ValueOfAccount4_4[#{ITERATOR}]"
            }
          },
          'accountValueOverflow' => {
            key: "accountValueOverflow[#{ITERATOR}]", # Fake key for overflow handling
            limit: 14,
            dollar: true,
            question_num: 4,
            question_suffix: '(6)',
            question_text: 'VALUE OF ACCOUNT',
            question_label: 'Account Value'
          }
        }
      }.freeze

      ##
      # Expands associated incomes by processing each income entry and setting an indicator
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        associated_incomes = form_data['associatedIncomes']
        form_data['associatedIncome'] = radio_yesno(associated_incomes&.length)
        form_data['associatedIncomes'] = associated_incomes&.map do |item|
          expand_item(item)
        end
      end

      ##
      # Expands an associated income entry by mapping relationships and income types
      # to predefined constants and formatting financial values.
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        income_type = item['incomeType']
        gross_monthly_income = item['grossMonthlyIncome']
        account_value = item['accountValue']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => item['otherRecipientRelationshipType'],
          'recipientName' => item['recipientName'],
          'payer' => item['payer'],
          'incomeType' => IncomeAndAssets::Constants::ACCOUNT_INCOME_TYPES[income_type],
          'incomeTypeOverflow' => income_type,
          'otherIncomeType' => item['otherIncomeType'],
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => ActiveSupport::NumberHelper.number_to_currency(gross_monthly_income),
          'accountValue' => split_currency_amount_lg(account_value),
          'accountValueOverflow' => ActiveSupport::NumberHelper.number_to_currency(account_value)
        }
      end
    end
  end
end
