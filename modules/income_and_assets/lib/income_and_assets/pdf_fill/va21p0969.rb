# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'income_and_assets/constants'
require 'income_and_assets/helpers'
require 'income_and_assets/pdf_fill/sections/section_06'
require 'income_and_assets/pdf_fill/sections/section_07'
require 'income_and_assets/pdf_fill/sections/section_08'
require 'income_and_assets/pdf_fill/sections/section_09'
require 'income_and_assets/pdf_fill/sections/section_10'
require 'income_and_assets/pdf_fill/sections/section_11'
require 'income_and_assets/pdf_fill/sections/section_12'
require 'income_and_assets/pdf_fill/sections/section_13'

module IncomeAndAssets
  module PdfFill
    # The Va21p0969 Form
    class Va21p0969 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include IncomeAndAssets::Helpers

      # The Form ID
      FORM_ID = IncomeAndAssets::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{IncomeAndAssets::MODULE_PATH}/lib/income_and_assets/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

      # Form configuration hash (using "key" instead of "KEY" here as we will be modifying this later)
      key = {
        # 1a
        'veteranFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: 'F[0].Page_4[0].VeteransName.First[0]'
          },
          'middle' => {
            key: 'F[0].Page_4[0].VeteransName.MI[0]'
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: 'F[0].Page_4[0].VeteransName.Last[0]'
          }
        },
        # 1b
        'veteranSocialSecurityNumber' => {
          key: 'F[0].Page_4[0].VeteransSSN[0]'
        },
        # 1c
        'vaFileNumber' => {
          key: 'F[0].Page_4[0].VeteransFileNumber[0]'
        },
        # 2a
        'claimantFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: 'F[0].Page_4[0].ClaimantsName.First[0]'
          },
          'middle' => {
            key: 'F[0].Page_4[0].ClaimantsName.MI[0]'
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: 'F[0].Page_4[0].ClaimantsName.Last[0]'
          }
        },
        # 2b
        'claimantSocialSecurityNumber' => {
          key: 'F[0].Page_4[0].ClaimantsSSN[0]'
        },
        # 2c
        'claimantPhone' => {
          key: 'F[0].Page_4[0].ClaimantTelephoneNumber[0]'
        },
        # 2d
        'claimantType' => {
          key: 'F[0].Page_4[0].TypeofClaimant[0]'
        },
        # 2e
        'incomeNetWorthDateRange' => {
          'from' => {
            key: 'F[0].Page_4[0].DateStarting[0]'
          },
          'to' => {
            key: 'F[0].Page_4[0].DateEnding[0]'
          },
          'useDateReceivedByVA' => {
            key: 'F[0].Page_4[0].DateReceivedByVA[0]'
          }
        },
        # 3a
        'unassociatedIncome' => {
          key: 'F[0].Page_4[0].DependentsReceiving3a[0]'
        },
        # 3b - 3f
        'unassociatedIncomes' => {
          limit: 5,
          first_key: 'recipientRelationship',
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients3[#{ITERATOR}]"
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
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          'incomeType' => {
            key: "F[0].TypeOfIncome3[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(3)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
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
            question_num: 3,
            question_suffix: '(4)',
            question_text: 'GROSS MONTHLY INCOME'
          },
          'payer' => {
            key: "F[0].IncomePayer3[#{ITERATOR}]",
            question_num: 3,
            question_suffix: '(5)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)'
          }
        },
        # 4a
        'associatedIncome' => {
          key: 'F[0].Page_6[0].DependentsReceiving4a[0]'
        },
        # 4b - 4f
        'associatedIncomes' => {
          limit: 5,
          first_key: 'recipientRelationship',
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients4[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 4,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship4[#{ITERATOR}]",
            question_num: 4,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient4[#{ITERATOR}]",
            question_num: 4,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          'payer' => {
            key: "F[0].IncomePayer4[#{ITERATOR}]",
            question_num: 4,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, or program, etc.)'
          },
          'incomeType' => {
            key: "F[0].TypeOfIncome4[#{ITERATOR}]"
          },
          'incomeTypeOverflow' => {
            question_num: 4,
            question_suffix: '(4)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
          'otherIncomeType' => {
            key: "F[0].OtherIncomeType4[#{ITERATOR}]",
            question_num: 4,
            question_suffix: '(4)',
            question_text: 'SPECIFY THE TYPE OF INCOME'
          },
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
            question_num: 4,
            question_suffix: '(5)',
            question_text: 'GROSS MONTHLY INCOME'
          },
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
            question_num: 4,
            question_suffix: '(6)',
            question_text: 'VALUE OF ACCOUNT'
          }
        },
        # 5a
        'ownedAsset' => {
          key: 'F[0].Page_8[0].DependentsReceiving5a[0]'
        },
        # 5b - 5d
        'ownedAssets' => {
          limit: 3,
          first_key: 'recipientRelationship',
          'recipientRelationship' => {
            key: "F[0].IncomeRecipients5[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 5,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship5[#{ITERATOR}]",
            question_num: 5,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient5[#{ITERATOR}]",
            question_num: 5,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          'assetType' => {
            key: "F[0].TypeOfAsset5[#{ITERATOR}]"
          },
          'assetTypeOverflow' => {
            question_num: 5,
            question_suffix: '(3)',
            question_text: 'IDENTIFY THE TYPE OF ASSET AND SUBMIT THE REQUIRED FORM ASSOCIATED'
          },
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
            question_text: 'GROSS MONTHLY INCOME'
          },
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
            question_text: 'SPECIFY VALUE OF YOUR PORTION OF THE PROPERTY'
          }
        },
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
      }

      # NOTE: Adding these over the span of multiple PRs too keep the LOC changed down.
      # Going to add them in reverse order so that the keys maintain the previous ordering
      SECTIONS = [Section6, Section7, Section8,
                  Section9, Section10, Section11,
                  Section12, Section13].freeze

      # Sections 6, 7, 8, 9, 10, 11, 12, and 13
      SECTIONS.each { |section| key = key.merge(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Post-process form data to match the expected format.
      # Each section of the form is processed in its own expand function.
      #
      # @param _options [Hash] any options needed for post-processing
      #
      # @return [Hash] the processed form data
      #
      def merge_fields(_options = {})
        expand_veteran_info
        expand_claimant_info
        expand_unassociated_incomes
        expand_associated_incomes
        expand_owned_assets

        # Sections 6, 7, 8, 9, 10, 11, 12, and 13
        SECTIONS.each { |section| section.new.expand(form_data) }

        form_data
      end

      private

      ##
      # Expands the veteran's information by extracting and capitalizing the first letter of the middle name.
      #
      # @note Modifies `form_data`
      #
      def expand_veteran_info
        veteran_middle_name = form_data['veteranFullName'].try(:[], 'middle')
        form_data['veteranFullName']['middle'] = veteran_middle_name.try(:[], 0)&.upcase
      end

      ##
      # Expands the claimants's information by extracting and capitalizing the first letter of the middle name.
      #
      # @note Modifies `form_data`
      #
      def expand_claimant_info
        claimant_middle_name = form_data['claimantFullName'].try(:[], 'middle')
        claimant_type = form_data['claimantType']
        net_worth_date_range = form_data['incomeNetWorthDateRange']

        form_data['claimantFullName']['middle'] = claimant_middle_name[0].upcase if claimant_middle_name.present?

        form_data['claimantType'] = IncomeAndAssets::Constants::CLAIMANT_TYPES[claimant_type]

        if net_worth_date_range.blank? || net_worth_date_range['from'].blank? || net_worth_date_range['to'].blank?
          form_data['incomeNetWorthDateRange'] = {
            'from' => nil,
            'to' => nil,
            'useDateReceivedByVA' => true
          }
        else
          form_data['incomeNetWorthDateRange'] = {
            'from' => format_date_to_mm_dd_yyyy(net_worth_date_range['from']),
            'to' => format_date_to_mm_dd_yyyy(net_worth_date_range['to']),
            'useDateReceivedByVA' => false
          }
        end
      end

      ##
      # Expands the unassociated incomes
      #
      # @note Modifies `form_data`
      #
      def expand_unassociated_incomes
        unassociated_incomes = form_data['unassociatedIncomes']
        form_data['unassociatedIncome'] = unassociated_incomes&.length ? 'YES' : 1
        form_data['unassociatedIncomes'] = unassociated_incomes&.map do |income|
          expand_unassociated_income(income)
        end
      end

      ##
      # Expands unassociated income details by mapping relationships and income types
      # to their respective constants and formatting the gross monthly income.
      #
      # @param income [Hash] The income data to be processed.
      # @return [Hash]
      #
      def expand_unassociated_income(income)
        recipient_relationship = income['recipientRelationship']
        income_type = income['incomeType']
        gross_monthly_income = income['grossMonthlyIncome']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => income['otherRecipientRelationshipType'],
          'recipientName' => income['recipientName'],
          'incomeType' => IncomeAndAssets::Constants::INCOME_TYPES[income_type],
          'incomeTypeOverflow' => income_type,
          'otherIncomeType' => income['otherIncomeType'],
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => gross_monthly_income,
          'payer' => income['payer']
        }
      end

      ##
      # Expands associated incomes by processing each income entry and setting an indicator
      #
      # @note Modifies `form_data`
      #
      def expand_associated_incomes
        associated_incomes = form_data['associatedIncomes']
        form_data['associatedIncome'] = associated_incomes&.length ? 0 : 1
        form_data['associatedIncomes'] = associated_incomes&.map do |income|
          expand_associated_income(income)
        end
      end

      ##
      # Expands an associated income entry by mapping relationships and income types
      # to predefined constants and formatting financial values.
      #
      # @param income [Hash]
      # @return [Hash]
      #
      def expand_associated_income(income)
        recipient_relationship = income['recipientRelationship']
        income_type = income['incomeType']
        gross_monthly_income = income['grossMonthlyIncome']
        account_value = income['accountValue']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => income['otherRecipientRelationshipType'],
          'recipientName' => income['recipientName'],
          'payer' => income['payer'],
          'incomeType' => IncomeAndAssets::Constants::ACCOUNT_INCOME_TYPES[income_type],
          'incomeTypeOverflow' => income_type,
          'otherIncomeType' => income['otherIncomeType'],
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => gross_monthly_income,
          'accountValue' => split_currency_amount_lg(account_value),
          'accountValueOverflow' => account_value
        }
      end

      ##
      # Expands owned assets by processing each asset entry and setting an indicator
      # based on the presence of owned assets.
      #
      # @note Modifies `form_data`
      #
      def expand_owned_assets
        owned_assets = form_data['ownedAssets']
        form_data['ownedAsset'] = owned_assets&.length ? 0 : 1
        form_data['ownedAssets'] = owned_assets&.map do |asset|
          expand_owned_asset(asset)
        end
      end

      ##
      # Expands an owned asset entry by mapping relationships and asset types
      # to predefined constants and formatting financial values.
      #
      # @param asset [Hash]
      # @return [Hash]
      #
      def expand_owned_asset(asset)
        recipient_relationship = asset['recipientRelationship']
        asset_type = asset['assetType']
        gross_monthly_income = asset['grossMonthlyIncome']
        portion_value = asset['ownedPortionValue']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'otherRecipientRelationshipType' => asset['otherRecipientRelationshipType'],
          'recipientName' => asset['recipientName'],
          'assetType' => IncomeAndAssets::Constants::ASSET_TYPES[asset_type],
          'assetTypeOverflow' => asset_type,
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => gross_monthly_income,
          'ownedPortionValue' => split_currency_amount_lg(portion_value),
          'ownedPortionValueOverflow' => portion_value
        }
      end
    end
  end
end
