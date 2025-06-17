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
            question_label: 'Relationship'
          },
          'otherOriginalOwnerRelationshipType' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(1)',
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
            question_label: 'Transfer Method'
          },
          'otherTransferMethod' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(2)',
            question_text: 'SPECIFY HOW THE ASSET WAS TRANSFERRED (OTHER)',
            question_label: 'Other Transfer Method'
          },
          # Q3
          'assetType' => {
            key: "F[0].WhatAssetWasTransferred[#{ITERATOR}]"
          },
          'assetTypeOverflow' => {
            question_num: 7,
            question_suffix: '(3)',
            question_text: 'WHAT ASSET WAS TRANSFERRED?',
            question_label: 'What Was Transferred'
          },
          # Q4
          'newOwnerName' => {
            key: "F[0].WhoReceivedAsset[#{ITERATOR}]"
          },
          'newOwnerNameOverflow' => {
            question_num: 7,
            question_suffix: '(4)',
            question_text: 'WHO RECEIVED THE ASSET?',
            question_label: 'New Owner Name'
          },
          # Q5
          'newOwnerRelationship' => {
            key: "F[0].RelationshipToNewOwner[#{ITERATOR}]"
          },
          'newOwnerRelationshipOverflow' => {
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
            question_label: 'Sale Reported to IRS'
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
            key: "F[0].TransferredForLessThanFMV[#{ITERATOR}]"
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
        form_data['assetTransfer'] = transfers&.length ? 0 : 1
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
          'assetTypeOverflow' => item['assetType'],
          'newOwnerName' => new_owner_name,
          'newOwnerNameOverflow' => new_owner_name,
          'newOwnerRelationship' => item['newOwnerRelationship'],
          'newOwnerRelationshipOverflow' => item['newOwnerRelationship'],
          'saleReportedToIrs' => item['saleReportedToIrs'] ? 0 : 1,
          'transferDate' => split_date(item['transferDate']),
          'assetTransferredUnderFairMarketValue' => item['assetTransferredUnderFairMarketValue'] ? 0 : 1,
          'fairMarketValue' => split_currency_amount_lg(item['fairMarketValue']),
          'fairMarketValueOverflow' => item['fairMarketValue'],
          'saleValue' => split_currency_amount_lg(item['saleValue']),
          'saleValueOverflow' => item['saleValue'],
          'capitalGainValue' => split_currency_amount_lg(item['capitalGainValue']),
          'capitalGainValueOverflow' => item['capitalGainValue']
        }
      end
    end
  end
end
