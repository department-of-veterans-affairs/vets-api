# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section X: Unreported Assets
    class Section10 < Section
      # Section configuration hash
      KEY = {
        # 10a
        'unreportedAsset' => { key: 'F[0].#subform[8].DependentsHaveAssetsNotReported10a[0]' },
        # 10b-e (only space for four on form)
        'unreportedAssets' => {
          # Label for each unreported asset (e.g., 'Unreported Asset 1')
          item_label: 'Unreported Asset',
          limit: 4,
          first_key: 'otherRelationshipType',
          # Q1
          'assetOwnerRelationship' => { key: "F[0].RelationshipToVeteran10[#{ITERATOR}]" },
          'assetOwnerRelationshipOverflow' => {
            question_num: 10,
            question_suffix: '(1)',
            question_text: "SPECIFY ASSET OWNER'S RELATIONSHIP TO THE VETERAN",
            question_label: 'Asset Owner Relationship'
          },
          'otherRelationshipType' => {
            key: "F[0].OtherRelationship10[#{ITERATOR}]",
            question_num: 10,
            question_suffix: '(1)',
            question_text: "SPECIFY ASSET OWNER'S RELATIONSHIP TO THE VETERAN",
            question_label: 'Other Relationship Type'
          },
          # Q2
          'assetType' => {
            key: "F[0].TypeOfAsset10[#{ITERATOR}]",
            question_num: 10,
            question_suffix: '(2)',
            question_text: 'SPECIFY TYPE OF ASSET (Cash, art, etc.)',
            question_label: 'Asset Type'
          },
          # Q3
          'ownedPortionValue' => {
            'millions' => { key: "F[0].ValueOfYourPortionOfProperty1_10[#{ITERATOR}]" },
            'thousands' => { key: "F[0].ValueOfYourPortionOfProperty2_10[#{ITERATOR}]" },
            'dollars' => { key: "F[0].ValueOfYourPortionOfProperty3_10[#{ITERATOR}]" },
            'cents' => { key: "F[0].ValueOfYourPortionOfProperty4_10[#{ITERATOR}]" }
          },
          'ownedPortionValueOverflow' => {
            dollar: true,
            question_num: 10,
            question_suffix: '(3)',
            question_text: 'SPECIFY VALUE OF YOUR PORTION OF THE PROPERTY',
            question_label: 'Owned Portion Value'
          },
          # Q4
          'assetLocation' => {
            key: "F[0].AssetLocation[#{ITERATOR}]",
            question_num: 10,
            question_suffix: '(4)',
            question_text: 'SPECIFY ASSET LOCATION (Financial institution, property address, etc.)',
            question_label: 'Asset Location'
          }
        }
      }.freeze

      ##
      # Expands and transforms the `unreportedAssets` field in the form data.
      #
      # @param form_data [Hash]
      #
      # If `unreportedAssets` is present and not empty, sets a flag `unreportedAssets` to 0,
      # otherwise sets it to 1. Then maps over the assets to apply individual transformations.
      #
      # @note Modifies `@form_data`
      #
      def expand(form_data)
        assets = form_data['unreportedAssets']
        form_data['unreportedAsset'] = assets&.length ? 0 : 1
        form_data['unreportedAssets'] = assets&.map { |item| expand_item(item) }
      end

      ##
      # Expands an unreported asset's data by processing its attributes and transforming them
      # into structured output
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        expanded = {
          'assetOwnerRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[item['assetOwnerRelationship']],
          'recipientName' => item['recipientName'],
          'assetType' => item['assetType'],
          'ownedPortionValue' => split_currency_amount(item['ownedPortionValue']),
          'assetLocation' => item['assetLocation']
        }

        overflow = {}
        expanded.each_key do |fieldname|
          overflow["#{fieldname}Overflow"] = item[fieldname]
        end

        expanded.merge(overflow)
      end
    end
  end
end
