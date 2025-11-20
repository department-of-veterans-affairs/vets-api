# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section VII: Asset Transfers
    class Section7 < Section
      # Section configuration hash
      KEY = {
        # 7a
        'assetTransfer' => {
          key: 'F[0].Page_9[0].DependentsSellAssets7a[0]'
        },
        # 7b-7d (only space for three on form)
        'assetTransfers' => {
          # Label for each transfer entry (e.g., 'Asset Transfer 1')
          item_label: 'Asset Transfer',
          limit: 3,
          first_key: 'otherOriginalOwnerRelationshipType',
          # Q1
          'originalOwnerRelationship' => {
            key: "F[0].RelationshiptoVeteran7[#{ITERATOR}]"
          },
          'originalOwnerRelationshipOverflow' => {
            question_num: 7,
            question_suffix: '(1)',
            question_text: "SPECIFY ASSET'S ORIGINAL OWNER'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship to Veteran',
            format_options: {
              humanize: true
            }
          },
          'otherOriginalOwnerRelationshipType' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            limit: 22,
            question_num: 7,
            question_suffix: '(1)(OTHER)',
            question_text: "SPECIFY ASSET'S ORIGINAL OWNER'S RELATIONSHIP TO VETERAN (OTHER)",
            question_label: 'Relationship Type'
          },
          # Q2
          'transferMethod' => {
            key: "F[0].HowAssetTransferred[#{ITERATOR}]"
          },
          'transferMethodOverflow' => {
            question_num: 7,
            question_suffix: '(2)',
            question_text: 'SPECIFY HOW THE ASSET WAS TRANSFERRED',
            question_label: 'Transfer Method',
            format_options: {
              humanize: true
            }
          },
          'otherTransferMethod' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            limit: 33,
            question_num: 7,
            question_suffix: '(2)(OTHER)',
            question_text: 'SPECIFY HOW THE ASSET WAS TRANSFERRED (OTHER)',
            question_label: 'Other Transfer Method'
          },
          # Q3
          'assetType' => {
            key: "F[0].WhatAssetWasTransferred[#{ITERATOR}]",
            limit: 46,
            question_num: 7,
            question_suffix: '(3)',
            question_text: 'WHAT ASSET WAS TRANSFERRED?',
            question_label: 'Asset Type'
          },
          # Q4
          'newOwnerName' => {
            key: "F[0].WhoReceivedAsset[#{ITERATOR}]",
            limit: 46,
            question_num: 7,
            question_suffix: '(4)',
            question_text: 'WHO RECEIVED THE ASSET?',
            question_label: 'New Owner Name'
          },
          # Q5
          'newOwnerRelationship' => {
            key: "F[0].RelationshipToNewOwner[#{ITERATOR}]",
            limit: 46,
            question_num: 7,
            question_suffix: '(5)',
            question_text: 'RELATIONSHIP TO NEW OWNER',
            question_label: 'Relationship to New Owner'
          },
          # Q6
          'saleReportedToIrs' => {
            key: "F[0].WasSaleReportedToIRS[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(6)',
            question_text: 'WAS THE SALE REPORTED TO THE IRS?',
            question_label: 'Sale Reported to IRS',
            format_options: {
              humanize: {
                '0' => 'Yes',
                '1' => 'No'
              }
            }
          },
          # Q7
          'transferDate' => {
            'month' => {
              key: "F[0].DateOfTransferMonth[#{ITERATOR}]"
            },
            'day' => {
              key: "F[0].DateOfTransferDay[#{ITERATOR}]"
            },
            'year' => {
              key: "F[0].DateOfTransferYear[#{ITERATOR}]"
            }
          },
          # Q8
          'assetTransferredUnderFairMarketValue' => {
            key: "F[0].TransferredForLessThanFMV[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(8)',
            question_text: 'WAS THE ASSET TRANSFERRED FOR LESS THAN FAIR MARKET VALUE?',
            question_label: 'Transferred Under Fair Market Value',
            format_options: {
              humanize: {
                '0' => 'Yes',
                '1' => 'No'
              }
            }
          },
          # Q9
          'fairMarketValue' => {
            'millions' => {
              key: "F[0].FairMarketValue1_7[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].FairMarketValue2_7[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].FairMarketValue3_7[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].FairMarketValue4_7[#{ITERATOR}]"
            }
          },
          'fairMarketValueOverflow' => {
            limit: 14,
            dollar: true,
            question_num: 7,
            question_suffix: '(9)',
            question_text: 'WHAT WAS THE FAIR MARKET VALUE WHEN TRANSFERRED?',
            question_label: 'Fair Market Value'
          },
          # Q10
          'saleValue' => {
            'millions' => {
              key: "F[0].SalePrice1_7[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].SalePrice2_7[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].SalePrice3_7[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].SalePrice4_7[#{ITERATOR}]"
            }
          },
          'saleValueOverflow' => {
            limit: 14,
            dollar: true,
            question_num: 7,
            question_suffix: '(10)',
            question_text: 'WHAT WAS THE SALE PRICE? (If applicable)',
            question_label: 'Sale Price'
          },
          # Q11
          'capitalGainValue' => {
            'millions' => {
              key: "F[0].Gain1_7[#{ITERATOR}]"
            },
            'thousands' => {
              key: "F[0].Gain2_7[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].Gain3_7[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].Gain4_7[#{ITERATOR}]"
            }
          },
          'capitalGainValueOverflow' => {
            limit: 14,
            dollar: true,
            question_num: 7,
            question_suffix: '(11)',
            question_text: 'WHAT WAS THE GAIN? (Capital gain, etc.)',
            question_label: 'Capital Gain'
          }
        }
      }.freeze

      ##
      # Expands asset transfers by processing each transfer entry and setting an indicator
      # based on the presence of asset transfers.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        transfers = form_data['assetTransfers']
        form_data['assetTransfer'] = radio_yesno(transfers&.length)
        form_data['assetTransfers'] = transfers&.map { |item| expand_item(item) }
      end

      ##
      # Expands an asset transfer by mapping its details to structured output,
      # ensuring consistent formatting for relationships, transfer methods, and monetary values.
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item) # rubocop:disable Metrics/MethodLength
        original_owner_relationship = item['originalOwnerRelationship']
        transfer_method = item['transferMethod']
        new_owner_name = change_hash_to_string(item['newOwnerName'])
        {
          'originalOwnerRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[original_owner_relationship],
          'originalOwnerRelationshipOverflow' => item['originalOwnerRelationship'],
          'otherOriginalOwnerRelationshipType' => item['otherOriginalOwnerRelationshipType'],
          'transferMethod' => IncomeAndAssets::Constants::TRANSFER_METHODS[transfer_method],
          'transferMethodOverflow' => item['transferMethod'],
          'otherTransferMethod' => item['otherTransferMethod'],
          'assetType' => item['assetType'],
          'newOwnerName' => new_owner_name,
          'newOwnerRelationship' => item['newOwnerRelationship'],
          'saleReportedToIrs' => item['saleReportedToIrs'] ? 0 : 1,
          'transferDate' => split_date(item['transferDate']),
          'assetTransferredUnderFairMarketValue' => item['assetTransferredUnderFairMarketValue'] ? 0 : 1,
          'fairMarketValue' => split_currency_amount_lg(item['fairMarketValue']),
          'fairMarketValueOverflow' => ActiveSupport::NumberHelper.number_to_currency(item['fairMarketValue']),
          'saleValue' => split_currency_amount_lg(item['saleValue']),
          'saleValueOverflow' => ActiveSupport::NumberHelper.number_to_currency(item['saleValue']),
          'capitalGainValue' => split_currency_amount_lg(item['capitalGainValue']),
          'capitalGainValueOverflow' => ActiveSupport::NumberHelper.number_to_currency(item['capitalGainValue'])
        }
      end
    end
  end
end
