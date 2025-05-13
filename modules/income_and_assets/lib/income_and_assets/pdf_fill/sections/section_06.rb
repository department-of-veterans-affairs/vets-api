# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section VI: Royalties and Other Properties
    class Section6 < Section
      # Section configuration hash
      KEY = {
        # 6a
        'royaltiesAndOtherProperty' => {
          key: 'F[0].Page_9[0].DependentsReceiving6a[0]'
        },
        # 6b-c (only space for two on form)
        'royaltiesAndOtherProperties' => {
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients6[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 6,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship6[#{ITERATOR}]",
            question_num: 6,
            question_suffix: '(1)',
            question_text: 'RELATIONSHIP TYPE OTHER'
          },
          # Q2
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient6[#{ITERATOR}]",
            limit: 37,
            question_num: 6,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          # Q3
          'incomeGenerationMethod' => {
            key: "F[0].HowIncomeIsGenerated6[#{ITERATOR}]"
          },
          'incomeGenerationMethodOverflow' => {
            question_num: 6,
            question_suffix: '(3)',
            question_text: 'SPECIFY HOW INCOME IS GENERATED'
          },
          'otherIncomeType' => {
            limit: 73,
            question_num: 6,
            question_suffix: '(3)',
            question_text: 'INCOME TYPE OTHER',
            key: "F[0].OtherIncomeGenerationMethod6[#{ITERATOR}]"
          },
          # Q4
          'grossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].GrossMonthlyIncome1_6[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossMonthlyIncome2_6[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossMonthlyIncome3_6[#{ITERATOR}]"
            }
          },
          'grossMonthlyIncomeOverflow' => {
            question_num: 6,
            question_suffix: '(4)',
            question_text: 'GROSS MONTHLY INCOME'
          },
          # Q5
          'fairMarketValue' => {
            'millions' => {
              key: "F[0].FairMarketValue1_6[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].FairMarketValue2_6[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].FairMarketValue3_6[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].FairMarketValue4_6[#{ITERATOR}]"
            }
          },
          'fairMarketValueOverflow' => {
            question_num: 6,
            question_suffix: '(5)',
            question_text: 'SPECIFY FAIR MARKET VALUE OF THIS ASSET'
          },
          # Q6
          'canBeSold' => {
            key: "F[0].CanAssetBeSold6[#{ITERATOR}]"
          },
          'canBeSoldOverflow' => {
            question_num: 6,
            question_suffix: '(6)',
            question_text: 'CAN THIS ASSET BE SOLD?'
          },
          # Q7
          'mitigatingCircumstances' => {
            limit: 172,
            question_num: 6,
            question_suffix: '(7)',
            question_text: 'EXPLAIN ANY MITIGATING CIRCUMSTANCES THAT PREVENT THE SALE OF THIS ASSET',
            key: "F[0].MitigatingCircumstances6[#{ITERATOR}]"
          }
        }
      }.freeze

      ##
      # Expands the royalties and other properties data in the form.
      #
      # This method processes the `royaltiesAndOtherProperties` field from the `form_data` hash.
      # It sets the `royaltiesAndOtherProperty` field to `0` if `royaltiesAndOtherProperties` has any elements,
      # otherwise it sets it to `1`. Then, it iterates over each property in `royaltiesAndOtherProperties`,
      # merging it with the result of the `expand_royalties_and_other_property` method.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        rop = form_data['royaltiesAndOtherProperties']
        form_data['royaltiesAndOtherProperty'] = rop&.length ? 0 : 1
        form_data['royaltiesAndOtherProperties'] = rop&.map do |item|
          item.merge(expand_item(item))
        end
      end

      ##
      # Expands the details of a property related to royalties and other income-generating assets.
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        income_type = item['incomeGenerationMethod']
        gross_monthly_income = item['grossMonthlyIncome']
        fair_market_value = item['fairMarketValue']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'incomeGenerationMethod' => IncomeAndAssets::Constants::INCOME_GENERATION_TYPES[income_type],
          'incomeGenerationMethodOverflow' => income_type,
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => number_to_currency(gross_monthly_income),
          'fairMarketValue' => split_currency_amount_lg(fair_market_value),
          'fairMarketValueOverflow' => number_to_currency(fair_market_value),
          'canBeSold' => item['canBeSold'] ? 0 : 1,
          'canBeSoldOverflow' => item['canBeSold']
        }
      end
    end
  end
end
