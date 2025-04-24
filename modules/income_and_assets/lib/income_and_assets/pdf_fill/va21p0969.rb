# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'income_and_assets/constants'
require 'income_and_assets/helpers'
require 'income_and_assets/pdf_fill/sections/section_09'
require 'income_and_assets/pdf_fill/sections/section_10'
require 'income_and_assets/pdf_fill/sections/section_11'
require 'income_and_assets/pdf_fill/sections/section_12'
require 'income_and_assets/pdf_fill/sections/section_13'

# rubocop:disable Metrics/ClassLength

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
        # 6b-c
        'royaltiesAndOtherProperties' => {
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
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
          'recipientName' => {
            key: "F[0].NameofIncomeRecipient6[#{ITERATOR}]",
            limit: 37,
            question_num: 6,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
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
          'canBeSold' => {
            key: "F[0].CanAssetBeSold6[#{ITERATOR}]"
          },
          'canBeSoldOverflow' => {
            question_num: 6,
            question_suffix: '(6)',
            question_text: 'CAN THIS ASSET BE SOLD?'
          },
          'mitigatingCircumstances' => {
            limit: 172,
            question_num: 6,
            question_suffix: '(7)',
            question_text: 'EXPLAIN ANY MITIGATING CIRCUMSTANCES THAT PREVENT THE SALE OF THIS ASSET',
            key: "F[0].MitigatingCircumstances6[#{ITERATOR}]"
          }
        },
        # 7a
        'assetTransfer' => {
          key: 'F[0].Page_9[0].DependentsSellAssets7a[0]'
        },
        # 7b-7d
        'assetTransfers' => {
          limit: 3,
          first_key: 'originalOwnerRelationship',
          'originalOwnerRelationship' => {
            key: "F[0].RelationshiptoVeteran7[#{ITERATOR}]"
          },
          'originalOwnerRelationshipOverflow' => {
            question_num: 7,
            question_suffix: '(1)',
            question_text: "SPECIFY ASSET'S ORIGINAL OWNER'S RELATIONSHIP TO VETERAN"
          },
          'otherOriginalOwnerRelationshipType' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(1)',
            question_text: "SPECIFY ASSET'S ORIGINAL OWNER'S RELATIONSHIP TO VETERAN (OTHER)"
          },
          'transferMethod' => {
            key: "F[0].HowAssetTransferred[#{ITERATOR}]"
          },
          'transferMethodOverflow' => {
            question_num: 7,
            question_suffix: '(2)',
            question_text: 'SPECIFY HOW THE ASSET WAS TRANSFERRED'
          },
          'otherTransferMethod' => {
            key: "F[0].OtherRelationship7[#{ITERATOR}]",
            question_num: 7,
            question_suffix: '(2)',
            question_text: 'SPECIFY HOW THE ASSET WAS TRANSFERRED (OTHER)'
          },
          'assetType' => {
            key: "F[0].WhatAssetWasTransferred[#{ITERATOR}]"
          },
          'assetTypeOverflow' => {
            question_num: 7,
            question_suffix: '(3)',
            question_text: 'WHAT ASSET WAS TRANSFERRED?'
          },
          'newOwnerName' => {
            key: "F[0].WhoReceivedAsset[#{ITERATOR}]"
          },
          'newOwnerNameOverflow' => {
            question_num: 7,
            question_suffix: '(4)',
            question_text: 'WHO RECEIVED THE ASSET?'
          },
          'newOwnerRelationship' => {
            key: "F[0].RelationshipToNewOwner[#{ITERATOR}]"
          },
          'newOwnerRelationshipOverflow' => {
            question_num: 7,
            question_suffix: '(5)',
            question_text: 'RELATIONSHIP TO NEW OWNER'
          },
          'saleReportedToIrs' => {
            key: "F[0].WasSaleReportedToIRS[#{ITERATOR}]"
          },
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
          'assetTransferredUnderFairMarketValue' => {
            key: "F[0].TransferredForLessThanFMV[#{ITERATOR}]"
          },
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
            question_num: 7,
            question_suffix: '(9)',
            question_text: 'WHAT WAS THE FAIR MARKET VALUE WHEN TRANSFERRED?'
          },
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
            question_num: 7,
            question_suffix: '(10)',
            question_text: 'WHAT WAS THE SALE PRICE? (If applicable)'
          },
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
            question_num: 7,
            question_suffix: '(11)',
            question_text: 'WHAT WAS THE GAIN? (Capital gain, etc.)'
          }
        },
        # 8a
        'trust' => { key: 'F[0].Page_10[0].DependentsEstablishedATrust[0]' },
        # 8b-8m (only space for one on form)
        'trusts' => {
          limit: 1,
          first_key: 'establishedDate',
          # 8b
          'establishedDate' => {
            'month' => { key: "F[0].Page_10[0].Month8b[#{ITERATOR}]" },
            'day' => { key: "F[0].Page_10[0].Day8b[#{ITERATOR}]" },
            'year' => { key: "F[0].Page_10[0].Year8b[#{ITERATOR}]" }
          },
          'establishedDateOverflow' => {
            question_num: 8,
            question_suffix: '(b)',
            question_text: 'DATE TRUST ESTABLISHED (MM/DD/YYYY)'
          },
          # 8c
          'marketValueAtEstablishment' => {
            'millions' => { key: "F[0].Page_10[0].MarketValue1_8c[#{ITERATOR}]" },
            'thousands' => { key: "F[0].Page_10[0].MarketValue2_8c[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].MarketValue3_8c[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].MarketValue4_8c[#{ITERATOR}]" }
          },
          'marketValueAtEstablishmentOverflow' => {
            question_num: 8,
            question_suffix: '(c)',
            question_text: 'SPECIFY MARKET VALUE OF ALL ASSETS WITHIN THE TRUST AT TIME OF ESTABLISHEMENT'
          },
          # 8d
          'trustType' => { key: "F[0].Page_10[0].TypeOfTrust8d[#{ITERATOR}]" },
          'trustTypeOverflow' => {
            question_num: 8,
            question_suffix: '(d)',
            question_text: 'SPECIFY TYPE OF TRUST ESTABLISHED'
          },
          # 8e
          'addedFundsAfterEstablishment' => { key: "F[0].Page_10[0].AddedAdditionalFunds8e[#{ITERATOR}]" },
          'addedFundsAfterEstablishmentOverflow' => {
            question_num: 8,
            question_suffix: '(e)',
            question_text: 'HAVE YOU ADDED FUNDS TO THE TRUST AFTER IT WAS ESTABLISHED?'
          },
          # 8f
          'addedFundsDate' => {
            'month' => { key: "F[0].Page_10[0].Transfer8fMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].Page_10[0].Transfer8fDay[#{ITERATOR}]" },
            'year' => { key: "F[0].Page_10[0].Transfer8fYear[#{ITERATOR}]" }
          },
          'addedFundsDateOverflow' => {
            question_num: 8,
            question_suffix: '(f)',
            question_text: 'WHEN DID YOU ADD FUNDS? (MM/DD/YYYY)'
          },
          # 8g
          'addedFundsAmount' => {
            'thousands' => { key: "F[0].Page_10[0].HowMuchTransferred1_8g[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].HowMuchTransferred2_8g[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].HowMuchTransferred3_8g[#{ITERATOR}]" }
          },
          'addedFundsAmountOverflow' => {
            question_num: 8,
            question_suffix: '(g)',
            question_text: 'HOW MUCH DID YOU ADD?'
          },
          # 8h
          'receivingIncomeFromTrust' => { key: "F[0].Page_10[0].ReceivingIncome8h[#{ITERATOR}]" },
          'receivingIncomeFromTrustOverflow' => {
            question_num: 8,
            question_suffix: '(h)',
            question_text: 'ARE YOU RECEIVING INCOME FROM THE TRUST? '
          },
          # 8i
          'annualReceivedIncome' => {
            'thousands' => { key: "F[0].Page_10[0].ReceiveAnnually1_8i[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].ReceiveAnnually2_8i[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].ReceiveAnnually3_8i[#{ITERATOR}]" }
          },
          'annualReceivedIncomeOverflow' => {
            question_num: 8,
            question_suffix: '(i)',
            question_text: 'HOW MUCH DO YOU RECEIVE ANNUALLY?'
          },
          # 8j
          'trustUsedForMedicalExpenses' => { key: "F[0].Page_10[0].TrustUsedToPay8j[#{ITERATOR}]" },
          'trustUsedForMedicalExpensesOverflow' => {
            question_num: 8,
            question_suffix: '(j)',
            question_text:
              'IS THE TRUST BEING USED TO PAY FOR OR TO REIMBURSE SOMEONE ELSE FOR YOUR MEDICAL EXPENSES?'
          },
          # 8k
          'monthlyMedicalReimbursementAmount' => {
            'thousands' => { key: "F[0].Page_10[0].ReimbursedMonthly1_8k[#{ITERATOR}]" },
            'dollars' => { key: "F[0].Page_10[0].ReimbursedMonthly2_8k[#{ITERATOR}]" },
            'cents' => { key: "F[0].Page_10[0].ReimbursedMonthly3_8k[#{ITERATOR}]" }
          },
          'monthlyMedicalReimbursementAmountOverflow' => {
            question_num: 8,
            question_suffix: '(k)',
            question_text: 'HOW MUCH IS BEING REIMBURSED MONTHLY?'
          },
          # 8l
          'trustEstablishedForVeteransChild' => { key: "F[0].Page_10[0].EstablishedForChild8l[#{ITERATOR}]" },
          'trustEstablishedForVeteransChildOverflow' => {
            question_num: 8,
            question_suffix: '(l)',
            question_text: 'WAS THE TRUST ESTABLISHED FOR A CHILD OF THE VETERAN WHO WAS INCAPABLE OF SELF-SUPPORT PRIOR TO REACHING AGE 18?' # rubocop:disable Layout/LineLength
          },
          # 8m
          'haveAuthorityOrControlOfTrust' => { key: "F[0].Page_10[0].AdditionalAuthority8m[#{ITERATOR}]" },
          'haveAuthorityOrControlOfTrustOverflow' => {
            question_num: 8,
            question_suffix: '(m)',
            question_text: 'DO YOU HAVE ANY ADDITIONAL AUTHORITY OR CONTROL OF THE TRUST?'
          }
        }
      }

      # NOTE: Adding these over the span of multiple PRs too keep the LOC changed down.
      # Going to add them in reverse order so that the keys maintain the previous ordering
      SECTIONS = [Section9, Section10, Section11, Section12, Section13].freeze

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
        expand_royalties_and_other_properties
        expand_asset_transfers
        expand_trusts

        # Sections 9, 10, 11, 12, and 13
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

      ##
      # Expands the royalties and other properties data in the form.
      #
      # This method processes the `royaltiesAndOtherProperties` field from the `form_data` hash.
      # It sets the `royaltiesAndOtherProperty` field to `0` if `royaltiesAndOtherProperties` has any elements,
      # otherwise it sets it to `1`. Then, it iterates over each property in `royaltiesAndOtherProperties`,
      # merging it with the result of the `expand_royalties_and_other_property` method.
      #
      # @return [void]
      #
      def expand_royalties_and_other_properties
        royalties_and_other_properties = form_data['royaltiesAndOtherProperties']
        form_data['royaltiesAndOtherProperty'] = royalties_and_other_properties&.length ? 0 : 1
        form_data['royaltiesAndOtherProperties'] = royalties_and_other_properties&.map do |property|
          property.merge(expand_royalties_and_other_property(property))
        end
      end

      ##
      # Expands the details of a property related to royalties and other income-generating assets.
      #
      # @param property [Hash]
      # @return [Hash]
      #
      def expand_royalties_and_other_property(property)
        recipient_relationship = property['recipientRelationship']
        income_type = property['incomeGenerationMethod']
        gross_monthly_income = property['grossMonthlyIncome']
        fair_market_value = property['fairMarketValue']
        {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'recipientRelationshipOverflow' => recipient_relationship,
          'incomeGenerationMethod' => IncomeAndAssets::Constants::INCOME_GENERATION_TYPES[income_type],
          'incomeGenerationMethodOverflow' => income_type,
          'grossMonthlyIncome' => split_currency_amount_sm(gross_monthly_income),
          'grossMonthlyIncomeOverflow' => number_to_currency(gross_monthly_income),
          'fairMarketValue' => split_currency_amount_lg(fair_market_value),
          'fairMarketValueOverflow' => number_to_currency(fair_market_value),
          'canBeSold' => property['canBeSold'] ? 0 : 1,
          'canBeSoldOverflow' => property['canBeSold']
        }
      end

      ##
      # Expands asset transfers by processing each transfer entry and setting an indicator
      # based on the presence of asset transfers.
      #
      # @note Modifies `form_data`
      #
      def expand_asset_transfers
        asset_transfers = form_data['assetTransfers']
        form_data['assetTransfer'] = asset_transfers&.length ? 0 : 1
        form_data['assetTransfers'] = asset_transfers&.map do |transfer|
          expand_asset_transfer(transfer)
        end
      end

      ##
      # Expands an asset transfer by mapping its details to structured output,
      # ensuring consistent formatting for relationships, transfer methods, and monetary values.
      #
      # @param transfer [Hash]
      # @return [Hash]
      #
      def expand_asset_transfer(transfer) # rubocop:disable Metrics/MethodLength
        original_owner_relationship = transfer['originalOwnerRelationship']
        transfer_method = transfer['transferMethod']
        new_owner_name = change_hash_to_string(transfer['newOwnerName'])
        {
          'originalOwnerRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[original_owner_relationship],
          'originalOwnerRelationshipOverflow' => transfer['originalOwnerRelationship'],
          'otherOriginalOwnerRelationshipType' => transfer['otherOriginalOwnerRelationshipType'],
          'transferMethod' => IncomeAndAssets::Constants::TRANSFER_METHODS[transfer_method],
          'transferMethodOverflow' => transfer['transferMethod'],
          'otherTransferMethod' => transfer['otherTransferMethod'],
          'assetType' => transfer['assetType'],
          'assetTypeOverflow' => transfer['assetType'],
          'newOwnerName' => new_owner_name,
          'newOwnerNameOverflow' => new_owner_name,
          'newOwnerRelationship' => transfer['newOwnerRelationship'],
          'newOwnerRelationshipOverflow' => transfer['newOwnerRelationship'],
          'saleReportedToIrs' => transfer['saleReportedToIrs'] ? 0 : 1,
          'transferDate' => split_date(transfer['transferDate']),
          'assetTransferredUnderFairMarketValue' => transfer['assetTransferredUnderFairMarketValue'] ? 0 : 1,
          'fairMarketValue' => split_currency_amount_lg(transfer['fairMarketValue']),
          'fairMarketValueOverflow' => transfer['fairMarketValue'],
          'saleValue' => split_currency_amount_lg(transfer['saleValue']),
          'saleValueOverflow' => transfer['saleValue'],
          'capitalGainValue' => split_currency_amount_lg(transfer['capitalGainValue']),
          'capitalGainValueOverflow' => transfer['capitalGainValue']
        }
      end

      ##
      # Expands trusts by processing each trust entry and setting an indicator
      # based on the presence of trusts.
      #
      # @note Modifies `form_data`
      #
      def expand_trusts
        trusts = form_data['trusts']
        form_data['trust'] = trusts&.length ? 0 : 1
        form_data['trusts'] = trusts&.map { |trust| expand_trust(trust) }
      end

      ##
      # Expands a trust's data by processing its attributes and transforming them into structured output
      #
      # @param trust [Hash]
      # @return [Hash]
      #
      def expand_trust(trust)
        market_value = split_currency_amount_lg(trust['marketValueAtEstablishment'], { 'millions' => 1 })
        expanded = {
          'establishedDate' => split_date(trust['establishedDate']),
          'marketValueAtEstablishment' => market_value,
          'trustType' => IncomeAndAssets::Constants::TRUST_TYPES[trust['trustType']],
          'addedFundsAfterEstablishment' => trust['addedFundsAfterEstablishment'] ? 0 : 1,
          'addedFundsDate' => split_date(trust['addedFundsDate']),
          'addedFundsAmount' => split_currency_amount_sm(trust['addedFundsAmount']),
          'receivingIncomeFromTrust' => trust['receivingIncomeFromTrust'] ? 0 : 1,
          'annualReceivedIncome' => split_currency_amount_sm(trust['annualReceivedIncome']),
          'trustUsedForMedicalExpenses' => trust['trustUsedForMedicalExpenses'] ? 0 : 1,
          'monthlyMedicalReimbursementAmount' => split_currency_amount_sm(trust['monthlyMedicalReimbursementAmount']),
          'trustEstablishedForVeteransChild' => trust['trustEstablishedForVeteransChild'] ? 0 : 1,
          'haveAuthorityOrControlOfTrust' => trust['haveAuthorityOrControlOfTrust'] ? 0 : 1
        }
        overflow = {}
        expanded.each_key do |fieldname|
          overflow["#{fieldname}Overflow"] = trust[fieldname]
        end
        expanded.merge(overflow)
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
