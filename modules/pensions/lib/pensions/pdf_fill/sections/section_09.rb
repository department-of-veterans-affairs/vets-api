# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section IX: Questions regarding income and assets
    class Section9 < Section
      # Section configuration hash
      KEY = {
        # 9a
        'totalNetWorth' => {
          key: 'form1[0].#subform[51].RadioButtonList[21]'
        },
        'netWorthEstimation' => {
          'part_two' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[1]'
          },
          'part_one' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[0]'
          }
        },
        # 9b
        'transferredAssets' => {
          key: 'form1[0].#subform[51].RadioButtonList[22]'
        },
        # 9c
        'homeOwnership' => {
          key: 'form1[0].#subform[51].RadioButtonList[23]'
        },
        # 9d
        'homeAcreageMoreThanTwo' => {
          key: 'form1[0].#subform[51].RadioButtonList[24]'
        },
        # 9e
        'homeAcreageValue' => {
          'part_three' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[1]'
          },
          'part_two' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[2]'
          },
          'part_one' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[0]'
          }
        },
        # 9f
        'landMarketable' => {
          key: 'form1[0].#subform[51].RadioButtonList[25]'
        },
        # 9g
        'moreThanFourIncomeSources' => {
          key: 'form1[0].#subform[51].RadioButtonList[26]'
        },
        # 9h-k Income Sources
        'incomeSources' => {
          item_label: 'Income source',
          limit: 4,
          first_key: 'dependentName',
          # (1) Recipient
          'receiver' => {
            key: "Income_Recipient[#{ITERATOR}]"
          },
          'receiverOverflow' => {
            question_num: 9,
            question_suffix: '(1)',
            question_label: 'Payment Recipient',
            question_text: 'PAYMENT RECIPIENT'
          },
          'dependentName' => {
            key: "Income_Recipient_Child[#{ITERATOR}]",
            limit: 29,
            question_num: 9,
            question_suffix: '(1)',
            question_label: "Child's Name",
            question_text: 'CHILD NAME'
          },
          # (2) Income Type
          'typeOfIncome' => {
            key: "Income_Type[#{ITERATOR}]"
          },
          'typeOfIncomeOverflow' => {
            question_num: 9,
            question_suffix: '(2)',
            question_label: 'Income Type',
            question_text: 'INCOME TYPE'
          },
          'otherTypeExplanation' => {
            key: "Other_Specify_Type_Of_Income[#{ITERATOR}]",
            limit: 31,
            question_num: 9,
            question_suffix: '(2)',
            question_label: 'Other Income Type Explanation',
            question_text: 'OTHER INCOME TYPE EXPLANATION'
          },
          # (3) Income Payer
          'payer' => {
            key: "Name_Of_Income_Payer[#{ITERATOR}]",
            limit: 25,
            question_num: 9,
            question_suffix: '(3)',
            question_label: 'Payer Name',
            question_text: 'PAYER NAME'
          },
          # (4) Gross Monthly Income
          'amount' => {
            'part_two' => {
              key: "Income_Monthly_Amount_First_Three[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Income_Monthly_Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Income_Monthly_Amount_Cents[#{ITERATOR}]"
            }
          },
          'amountOverflow' => {
            question_num: 9,
            question_suffix: '(4)',
            question_label: 'Current Gross Monthly Income',
            question_text: 'CURRENT GROSS MONTHLY INCOME'
          }
        }
      }.freeze

      ##
      # Processes income and asset-related questions, converting values to expected PDF formats.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['totalNetWorth'] = to_radio_yes_no(form_data['totalNetWorth'])
        if form_data['netWorthEstimation']
          form_data['netWorthEstimation'] =
            split_currency_amount(form_data['netWorthEstimation'])
        end
        form_data['transferredAssets'] = to_radio_yes_no(form_data['transferredAssets'])
        form_data['homeOwnership'] = to_radio_yes_no(form_data['homeOwnership'])
        if form_data['homeOwnership'].zero?
          form_data['homeAcreageMoreThanTwo'] = to_radio_yes_no(form_data['homeAcreageMoreThanTwo'])
          form_data['landMarketable'] = to_radio_yes_no(form_data['landMarketable'])
        end
        if form_data['homeAcreageValue'].present?
          form_data['homeAcreageValue'] =
            split_currency_amount(form_data['homeAcreageValue'])
        end
        form_data['moreThanFourIncomeSources'] =
          to_radio_yes_no(form_data['incomeSources'].present? && form_data['incomeSources'].length > 4)
        form_data['incomeSources'] = merge_income_sources(form_data['incomeSources'])
      end

      ##
      # Merge all income sources together and normalize the data.
      #
      # @param income_sources [Array<Hash>]
      #
      # @return [Array<Hash>] The merged and normalized income sources
      #
      def merge_income_sources(income_sources)
        income_sources&.map do |income_source|
          income_source_hash = {
            'receiver' => Constants::RECIPIENTS[income_source['receiver']],
            'receiverOverflow' => income_source['receiver']&.humanize,
            'typeOfIncome' => Constants::INCOME_TYPES[income_source['typeOfIncome']],
            'typeOfIncomeOverflow' => income_source['typeOfIncome']&.humanize,
            'amount' => split_currency_amount(income_source['amount']),
            'amountOverflow' => number_to_currency(income_source['amount'])
          }
          if income_source['dependentName'].present?
            income_source_hash['dependentName'] =
              income_source['dependentName']
          end
          income_source.merge(income_source_hash)
        end
      end
    end
  end
end
