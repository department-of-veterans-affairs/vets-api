# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'income_and_assets/constants'
require 'income_and_assets/helpers'

# rubocop:disable Metrics/ClassLength

module IncomeAndAssets::PdfFill
  # Forms
  module Forms
    # The Va21p0969 Form
    class Va21p0969 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include IncomeAndAssets::Helpers

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The ID of the form being processed
      FORM_ID = '21P-0969'

      # The path to the PDF template for the form
      TEMPLATE = "#{IncomeAndAssets::MODULE_PATH}/lib/income_and_assets/pdf_fill/forms/pdfs/#{FORM_ID}.pdf".freeze

      # Hash keys
      KEY = {
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
            question_text: 'IS THE TRUST BEING USED TO PAY FOR OR TO REIMBURSE SOMEONE ELSE FOR YOUR MEDICAL EXPENSES?'
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
        },
        # 9a
        'annuity' => { key: 'F[0].#subform[8].DependentsEstablishedAnnuity9a[0]' },
        'annuities' => {
          limit: 1,
          first_key: 'establishedDate',
          # 9b
          'establishedDate' => {
            'month' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedDay[#{ITERATOR}]" },
            'year' => { key: "F[0].#subform[8].DateAnnuityWasEstablishedYear[#{ITERATOR}]" }
          },
          'establishedDateOverflow' => {
            question_num: 9,
            question_suffix: '(b)',
            question_text: 'SPECIFY DATE ANNUITY WAS ESTABLISHED'
          },
          # 9c
          'marketValueAtEstablishment' => {
            'millions' => { key: "F[0].#subform[8].MarketAnnuity1_9c[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].MarketAnnuity2_9c[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].MarketAnnuity3_9c[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].MarketAnnuity4_9c[#{ITERATOR}]" }
          },
          'marketValueAtEstablishmentOverflow' => {
            question_num: 9,
            question_suffix: '(c)',
            question_text: 'SPECIFY MARKET VALUE OF ASSET AT TIME OF ANNUITY PURCHASE'
          },
          # 9d
          'addedFundsAfterEstablishment' => { key: 'F[0].#subform[8].AddedFundsToAnnuity9d[0]' },
          'addedFundsAfterEstablishmentOverflow' => {
            question_num: 9,
            question_suffix: '(d)',
            question_text: 'HAVE YOU ADDED FUNDS TO THE ANNUITY IN THE CURRENT OR PRIOR THREE YEARS?'
          },
          # 9e
          'addedFundsDate' => {
            'month' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredDay[#{ITERATOR}]" },
            'year' => { key: "F[0].#subform[8].DateAdditionalFundsTransferredYear[#{ITERATOR}]" }
          },
          'addedFundsDateOverflow' => {
            question_num: 9,
            question_suffix: '(e)',
            question_text: 'WHEN DID YOU ADD FUNDS?'
          },
          # 9f
          'addedFundsAmount' => {
            'millions' => { key: "F[0].#subform[8].HowMuchTransferred1_9f[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].HowMuchTransferred2_9f[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].HowMuchTransferred3_9f[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].HowMuchTransferred4_9f[#{ITERATOR}]" }
          },
          'addedFundsAmountOverflow' => {
            question_num: 9,
            question_suffix: '(f)',
            question_text: 'HOW MUCH DID YOU ADD?'
          },
          # 9g
          'revocable' => { key: "F[0].#subform[8].Annuity9g[#{ITERATOR}]" },
          'revocableOverflow' => {
            question_num: 9,
            question_suffix: '(g)',
            question_text: 'IS THE ANNUITY REVOCABLE OR IRREVOCABLE?'
          },
          # 9h
          'receivingIncomeFromAnnuity' => { key: "F[0].#subform[8].ReceiveIncomeFromAnnuity9h[#{ITERATOR}]" },
          'receivingIncomeFromAnnuityOverflow' => {
            question_num: 9,
            question_suffix: '(h)',
            question_text: 'DO YOU RECEIVE INCOME FROM THE ANNUNITY?'
          },
          # 9i
          'annualReceivedIncome' => {
            'millions' => { key: "F[0].#subform[8].AnnualAmountReceived1_9i[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].AnnualAmountReceived2_9i[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].AnnualAmountReceived3_9i[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].AnnualAmountReceived4_9i[#{ITERATOR}]" }
          },
          'annualReceivedIncomeOverflow' => {
            question_num: 9,
            question_suffix: '(i)',
            question_text: 'IF YES IN 9H, PROVIDE ANNUAL AMOUNT RECEIVED'
          },
          # 9j
          'canBeLiquidated' => { key: "F[0].#subform[8].AnnuityLiquidated9j[#{ITERATOR}]" },
          'canBeLiquidatedOverflow' => {
            question_num: 9,
            question_suffix: '(j)',
            question_text: 'CAN THE ANNUITY BE LIQUIDATED?'
          },
          # 9k
          'surrenderValue' => {
            'millions' => { key: "F[0].#subform[8].SurrenderValue1_9k[#{ITERATOR}]" },
            'thousands' => { key: "F[0].#subform[8].SurrenderValue2_9k[#{ITERATOR}]" },
            'dollars' => { key: "F[0].#subform[8].SurrenderValue3_9k[#{ITERATOR}]" },
            'cents' => { key: "F[0].#subform[8].SurrenderValue4_9k[#{ITERATOR}]" }
          },
          'surrenderValueOverflow' => {
            question_num: 9,
            question_suffix: '(k)',
            question_text: 'IF YES IN 9J, PROVIDE THE SURRENDER VALUE'
          }
        },
        # Section 11
        # 11a
        'discontinuedIncome' => { key: 'F[0].#subform[9].DependentReceiveIncome11a[0]' },
        # 11b-11c (only space for 2 on form)
        'discontinuedIncomes' => {
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].RelationshipToVeteran11[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          # Q2
          'recipientName' => {
            key: "F[0].IncomeRecipientName11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(2)',
            question_text:
              'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, etc.)'
          },
          # Q4
          'incomeType' => {
            key: "F[0].TypeOfIncomeReceived11[#{ITERATOR}]",
            question_num: 11,
            question_suffix: '(4)',
            question_text: 'SPECIFY TYPE OF INCOME RECEIVED (Interest, dividends, etc.)'
          },
          # Q5
          'incomeFrequency' => {
            key: "F[0].FrequencyOfIncomeReceived[#{ITERATOR}]"
          },
          'incomeFrequencyOverflow' => {
            question_num: 11,
            question_suffix: '(5)',
            question_text: 'SPECIFY FREQUENCY OF INCOME RECEIVED'
          },
          # Q6
          'incomeLastReceivedDate' => {
            'month' => { key: "F[0].DateIncomeLastPaidMonth11[#{ITERATOR}]" },
            'day' => { key: "F[0].DateIncomeLastPaidDay11[#{ITERATOR}]" },
            'year' => { key: "F[0].DateIncomeLastPaidYear11[#{ITERATOR}]" }
          },
          'incomeLastReceivedDateOverflow' => {
            question_num: 11,
            question_suffix: '(6)',
            question_text: 'DATE INCOME LAST PAID (MM/DD/YYYY)'
          },
          # Q7
          'grossAnnualAmount' => {
            'thousands' => {
              key: "F[0].GrossAnnualAmount1_11[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].GrossAnnualAmount2_11[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].GrossAnnualAmount3_11[#{ITERATOR}]"
            }
          },
          'grossAnnualAmountOverflow' => {
            question_num: 11,
            question_suffix: '(7)',
            question_text: 'WHAT WAS THE GROSS ANNUAL AMOUNT REPORTED TO THE IRS?'
          }
        },
        # Section 12
        # 12a
        'incomeReceiptWaiver' => { key: 'F[0].#subform[9].DependentsWaiveReceiptsOfIncome12a[0]' },
        # 12b-12c (only space for 2 on form)
        'incomeReceiptWaivers' => {
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].RelationshipToVeteran12[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 12,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN"
          },
          # Q2
          'recipientName' => {
            key: "F[0].IncomeRecipientName12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(2)',
            question_text:
                'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, etc.)'
          },
          # Q4
          'expectedIncome' => {
            'thousands' => {
              key: "F[0].AmountExpected1[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].AmountExpected2[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].AmountExpected3[#{ITERATOR}]"
            }
          },
          'expectedIncomeOverflow' => {
            question_num: 12,
            question_suffix: '(4)',
            question_text: 'IF THE INCOME RESUMES, WHAT AMOUNT DO YOU EXPECT TO RECEIVE?'
          },
          # Q5
          'paymentResumeDate' => {
            'month' => { key: "F[0].DatePaymentsResumeMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].DatePaymentsResumeDay[#{ITERATOR}]" },
            'year' => { key: "F[0].DatePaymentsResumeYear[#{ITERATOR}]" }
          },
          'paymentResumeDateOverflow' => {
            question_num: 12,
            question_suffix: '(5)',
            question_text: 'DATE PAYMENTS WILL RESUME (MM/DD/YYYY)'
          },
          'paymentWillNotResume' => {
            key: "F[0].IncomeWillNotResume12[#{ITERATOR}]"
          },
          'paymentWillNotResumeOverflow' => {
            question_num: 12,
            question_suffix: '(5)',
            question_text: 'This income will not resume'
          },
          # Q6
          'waivedGrossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].WaivedGrossMonthlyIncome1[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].WaivedGrossMonthlyIncome2[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].WaivedGrossMonthlyIncome3[#{ITERATOR}]"
            }
          },
          'waivedGrossMonthlyIncomeOverflow' => {
            question_num: 12,
            question_suffix: '(6)',
            question_text: 'WAIVED GROSS MONTHLY INCOME'
          }
        },
        # Section 13
        # NOTE: No overflow for this section
        # 13a
        'statementOfTruthSignature' => { key: 'F[0].#subform[9].SignatureField11[0]' },
        # 13b
        'statementOfTruthDate' => {
          'month' => { key: 'F[0].DateSigned13bMonth[0]' },
          'day' => { key: 'F[0].DateSigned13bDay[0]' },
          'year' => { key: 'F[0].DateSigned13bYear[0]' }
        }
      }.freeze

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
        expand_asset_transfers
        expand_trusts
        expand_annuities
        expand_discontinued_incomes
        expand_income_receipt_waivers
        expand_statement_of_truth

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

      # Section 9
      ##
      # Expands annuities by processing each annuity entry and setting an indicator
      # based on the presence of annuities.
      #
      # @note Modifies `form_data`
      #
      def expand_annuities
        annuities = form_data['annuities']
        form_data['annuity'] = annuities&.length ? 0 : 1
        form_data['annuities'] = annuities&.map { |annuity| expand_annuity(annuity) }
      end

      ##
      # Expands a annuity's data by processing its attributes and transforming them into structured output
      #
      # @param annuity [Hash]
      # @return [Hash]
      #
      def expand_annuity(annuity)
        market_value = split_currency_amount_lg(annuity['marketValueAtEstablishment'], { 'millions' => 1 })
        expanded = {
          'addedFundsDate' => split_date(annuity['addedFundsDate']),
          'addedFundsAmount' => split_currency_amount_lg(annuity['addedFundsAmount'], { 'millions' => 1 }),
          'addedFundsAfterEstablishment' => annuity['addedFundsAfterEstablishment'] ? 0 : 1,
          'canBeLiquidated' => annuity['canBeLiquidated'] ? 0 : 1,
          'surrenderValue' => split_currency_amount_lg(annuity['surrenderValue'], { 'millions' => 1 }),
          'receivingIncomeFromAnnuity' => annuity['receivingIncomeFromAnnuity'] ? 0 : 1,
          'annualReceivedIncome' => split_currency_amount_lg(annuity['annualReceivedIncome'], { 'millions' => 1 }),
          'revocable' => annuity['revocable'] ? 0 : 1,
          'establishedDate' => split_date(annuity['establishedDate']),
          'marketValueAtEstablishment' => market_value
        }
        overflow = {}
        expanded.each_key do |fieldname|
          overflow["#{fieldname}Overflow"] = annuity[fieldname]
        end
        expanded.merge(overflow)
      end

      # Section 11
      ##
      # Expands discontinued incomes by processing each discontinued income entry and setting an indicator
      # based on the presence of discontinued incomes.
      #
      # @note Modifies `form_data`
      #
      def expand_discontinued_incomes
        incomes = form_data['discontinuedIncomes']

        form_data['discontinuedIncome'] = incomes&.length ? 0 : 1
        form_data['discontinuedIncomes'] = incomes&.map { |income| expand_discontinued_income(income) }
      end

      ##
      # Expands a discontinued incomes's data by processing its attributes and transforming them into
      # structured output
      #
      # @param income [Hash]
      # @return [Hash]
      #
      def expand_discontinued_income(income)
        recipient_relationship = income['recipientRelationship']
        income_frequency = income['incomeFrequency']
        income_last_received_date = income['incomeLastReceivedDate']

        # NOTE: recipientName, payer, and incomeType are already part of the income hash
        # and do not need to be overflowed / overriden as they are free text fields
        overflow_fields = %w[recipientRelationship incomeFrequency
                             grossAnnualAmount]

        expanded = income.clone
        overflow_fields.each do |field|
          expanded["#{field}Overflow"] = income[field]
        end

        overrides = {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'incomeFrequency' => IncomeAndAssets::Constants::INCOME_FREQUENCIES[income_frequency],
          'incomeLastReceivedDate' => split_date(income_last_received_date),
          'incomeLastReceivedDateOverflow' => format_date_to_mm_dd_yyyy(income_last_received_date),
          'grossAnnualAmount' => split_currency_amount_sm(income['grossAnnualAmount'])
        }

        expanded.merge(overrides)
      end

      # Section 12
      ##
      # Expands income receipt waivers by processing each income receipt waiver entry and setting an indicator
      # based on the presence of income receipt waivers.
      #
      # @note Modifies `form_data`
      #
      def expand_income_receipt_waivers
        waivers = form_data['incomeReceiptWaivers']

        form_data['incomeReceiptWaiver'] = waivers&.length ? 0 : 1
        form_data['incomeReceiptWaivers'] = waivers&.map { |waiver| expand_income_receipt_waiver(waiver) }
      end

      ##
      # Expands a income receipt waivers's data by processing its attributes and transforming them into
      # structured output
      #
      # @param waiver [Hash]
      # @return [Hash]
      #
      def expand_income_receipt_waiver(waiver)
        recipient_relationship = waiver['recipientRelationship']
        payment_resume_date = waiver['paymentResumeDate']

        overflow_fields = %w[recipientRelationship expectedIncome waivedGrossMonthlyIncome]

        expanded = waiver.clone
        overflow_fields.each do |field|
          expanded["#{field}Overflow"] = waiver[field]
        end

        overrides = {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'expectedIncome' => split_currency_amount_sm(waiver['expectedIncome']),
          'paymentResumeDate' => split_date(payment_resume_date),
          'paymentResumeDateOverflow' => format_date_to_mm_dd_yyyy(payment_resume_date),
          'paymentWillNotResume' => payment_resume_date ? 0 : 1,
          'paymentWillNotResumeOverflow' => payment_resume_date ? 'NO' : 'YES',
          'waivedGrossMonthlyIncome' => split_currency_amount_sm(waiver['waivedGrossMonthlyIncome'])
        }

        expanded.merge(overrides)
      end

      # Section 13
      ##
      # Expands statement of truth section
      #
      # @note Modifies `form_data`
      #
      def expand_statement_of_truth
        # We want today's date in the form 'YYYY-MM-DD' as that's the format it comes
        # back from vets-website in
        form_data['statementOfTruthDate'] = split_date(Date.current.iso8601)
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
