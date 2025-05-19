# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section V: Owned Assets
    class Section5 < Section
      # Section configuration hash
      KEY = {
        # 5a
        'ownedAsset' => {
          key: 'F[0].Page_8[0].DependentsReceiving5a[0]'
        },
        # 5b - 5d (only space for three on form)
        'ownedAssets' => {
          # Label for each asset entry (e.g., 'Asset 1')
          item_label: 'Asset',
          limit: 3,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients5[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 5,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship'
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship5[#{ITERATOR}]",
            question_num: 5,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship Type'
          },
          # Q2
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient5[#{ITERATOR}]",
            question_num: 5,
            question_suffix: '(2)',
            question_text:
                      'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Name'
          },
          # Q3
          'assetType' => {
            key: "F[0].TypeOfAsset5[#{ITERATOR}]"
          },
          'assetTypeOverflow' => {
            question_num: 5,
            question_suffix: '(3)',
            question_text: 'IDENTIFY THE TYPE OF ASSET AND SUBMIT THE REQUIRED FORM ASSOCIATED',
            question_label: 'Asset Type'
          },
          # Q4
          'grossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].GrossMonthlyIncome1_5[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossMonthlyIncome2_5[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossMonthlyIncome3_5[#{ITERATOR}]"
            }
          },
          'grossMonthlyIncomeOverflow' => {
            question_num: 5,
            question_suffix: '(4)',
            question_text: 'GROSS MONTHLY INCOME',
            question_label: 'Gross Monthly Income'
          },
          # Q5
          'ownedPortionValue' => {
            'millions' => {
              key: "F[0].ValueOfYourPortionOfTheProperty1_5[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].ValueOfYourPortionOfTheProperty2_5[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].ValueOfYourPortionOfTheProperty3_5[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].ValueOfYourPortionOfTheProperty4_5[#{ITERATOR}]"
            }
          },
          'ownedPortionValueOverflow' => {
            question_num: 5,
            question_suffix: '(5)',
            question_text: 'SPECIFY VALUE OF YOUR PORTION OF THE PROPERTY',
            question_label: 'Owned Portion Value'
          }
        }
      }.freeze

      ##
      # Expands owned assets by processing each asset entry and setting an indicator
      # based on the presence of owned assets.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        owned_assets = form_data['ownedAssets']
        form_data['ownedAsset'] = owned_assets&.length ? 0 : 1
        form_data['ownedAssets'] = owned_assets&.map do |item|
          expand_item(item)
        end
      end

      ##
      # Expands an owned asset entry by mapping relationships and asset types
      # to predefined constants and formatting financial values.
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        asset_type = item['assetType']
        gross_monthly_income = item['grossMonthlyIncome']
        portion_value = item['ownedPortionValue']

        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => item['otherRecipientRelationshipType'],
          'recipientName' => item['recipientName'],
          'assetType' => IncomeAndAssets::Constants::ASSET_TYPES[asset_type],
          'assetTypeOverflow' => asset_type,
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => number_to_currency(gross_monthly_income),
          'ownedPortionValue' => split_currency_amount_lg(portion_value),
          'ownedPortionValueOverflow' => number_to_currency(portion_value)
        }
      end
    end
  end
end
