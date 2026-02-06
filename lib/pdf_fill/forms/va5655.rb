# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

require_relative 'form_base'
require_relative '../hash_converter'

module PdfFill
  module Forms
    class Va5655 < FormBase
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'personalIdentification' => {
          'ssn' => {
            key: 'vaco5655[0].#subform[0].Field1[0]',
            limit: 9,
            question_num: 1
          },
          'fileNumber' => {
            key: 'vaco5655[0].#subform[0].Field2[0]',
            question_num: 2
          },
          'fsrReason' => {
            key: 'vaco5655[0].#subform[0].Field3[0]',
            question_num: 3
          }
        },
        'personalData' => {
          'veteranFullName' => {
            key: 'vaco5655[0].#subform[0].Field4[0]',
            question_num: 4
          },
          'address' => {
            key: 'vaco5655[0].#subform[0].Field5[0]',
            question_num: 5
          },
          'telephoneNumber' => {
            key: 'vaco5655[0].#subform[0].Field6[0]',
            question_num: 6
          },
          'dateOfBirth' => {
            key: 'vaco5655[0].#subform[0].Field7[0]',
            question_num: 7
          },
          'married' => {
            key: 'vaco5655[0].#subform[0].RadioButtonList[0]',
            question_num: 8
          },
          'spouseFullName' => {
            key: 'vaco5655[0].#subform[0].Field10[0]',
            question_num: 9
          },
          'agesOfOtherDependents' => {
            key: 'vaco5655[0].#subform[0].Field11[0]',
            question_num: 10
          },
          'veteranCurrentEmployment' => {
            'kindOfJob' => {
              key: 'vaco5655[0].#subform[0].Field12[0]'
            },
            'fromDate' => {
              key: 'vaco5655[0].#subform[0].Field13[0]'
            },
            'employerName' => {
              key: 'vaco5655[0].#subform[0].Field14[0]'
            }
          },
          'veteranPastEmployment' => {
            'kindOfJob' => {
              key: 'vaco5655[0].#subform[0].Field15[0]'
            },
            'fromDate' => {
              key: 'vaco5655[0].#subform[0].Field16[0]'
            },
            'toDate' => {
              key: 'vaco5655[0].#subform[0].Field17[0]'
            },
            'employerName' => {
              key: 'vaco5655[0].#subform[0].Field18[0]'
            }
          },
          'spouseCurrentEmployment' => {
            'kindOfJob' => {
              key: 'vaco5655[0].#subform[0].Field19[0]'
            },
            'fromDate' => {
              key: 'vaco5655[0].#subform[0].Field20[0]'
            },
            'employerName' => {
              key: 'vaco5655[0].#subform[0].Field21[0]'
            }
          },
          'spousePastEmployment' => {
            'kindOfJob' => {
              key: 'vaco5655[0].#subform[0].Field22[0]'
            },
            'fromDate' => {
              key: 'vaco5655[0].#subform[0].Field23[0]'
            },
            'toDate' => {
              key: 'vaco5655[0].#subform[0].Field24[0]'
            },
            'employerName' => {
              key: 'vaco5655[0].#subform[0].Field25[0]'
            }
          }
        },
        'veteranIncome' => {
          'monthlyGrossSalary' => {
            key: 'vaco5655[0].#subform[0].Field26[0]',
            question_num: 13
          },
          'deductions' => {
            'taxes' => {
              key: 'vaco5655[0].#subform[0].Field28[0]',
              question_num: 14,
              question_suffix: 'A'
            },
            'retirement' => {
              key: 'vaco5655[0].#subform[0].Field30[0]',
              question_num: 14,
              question_suffix: 'B'
            },
            'socialSecurity' => {
              key: 'vaco5655[0].#subform[0].Field32[0]',
              question_num: 14,
              question_suffix: 'C'
            },
            'otherDeductions' => {
              'name' => {
                key: 'vaco5655[0].#subform[0].Field34[0]'
              },
              'amount' => {
                key: 'vaco5655[0].#subform[0].Field35[0]',
                question_num: 14,
                question_suffix: 'D'
              }
            }
          },
          'totalDeductions' => {
            key: 'vaco5655[0].#subform[0].Field37[0]',
            question_num: 14,
            question_suffix: 'E'
          },
          'netTakeHomePay' => {
            key: 'vaco5655[0].#subform[0].Field39[0]',
            question_num: 15
          },
          'otherIncome' => {
            'name' => {
              key: 'vaco5655[0].#subform[0].Field41[0]'
            },
            'amount' => {
              key: 'vaco5655[0].#subform[0].Field42[0]',
              question_num: 16
            }
          },
          'totalMonthlyNetIncome' => {
            key: 'vaco5655[0].#subform[0].Field44[0]',
            question_num: 17
          }
        },
        'spouseIncome' => {
          'monthlyGrossSalary' => {
            key: 'vaco5655[0].#subform[0].Field27[0]',
            question_num: 13
          },
          'deductions' => {
            'taxes' => {
              key: 'vaco5655[0].#subform[0].Field29[0]',
              question_num: 14,
              question_suffix: 'A'
            },
            'retirement' => {
              key: 'vaco5655[0].#subform[0].Field31[0]',
              question_num: 14,
              question_suffix: 'B'
            },
            'socialSecurity' => {
              key: 'vaco5655[0].#subform[0].Field33[0]',
              question_num: 14,
              question_suffix: 'C'
            },
            'otherDeductions' => {
              'amount' => {
                key: 'vaco5655[0].#subform[0].Field36[0]',
                question_num: 14,
                question_suffix: 'D'
              }
            }
          },
          'totalDeductions' => {
            key: 'vaco5655[0].#subform[0].Field38[0]',
            question_num: 14,
            question_suffix: 'E'
          },
          'netTakeHomePay' => {
            key: 'vaco5655[0].#subform[0].Field40[0]',
            question_num: 15
          },
          'otherIncome' => {
            'amount' => {
              key: 'vaco5655[0].#subform[0].Field43[0]',
              question_num: 16
            }
          },
          'totalMonthlyNetIncome' => {
            key: 'vaco5655[0].#subform[0].Field45[0]',
            question_num: 17
          }
        },
        'expenses' => {
          'rentOrMortgage' => {
            key: 'vaco5655[0].#subform[0].Field46[0]',
            question_num: 18
          },
          'food' => {
            key: 'vaco5655[0].#subform[0].Field47[0]',
            question_num: 19
          },
          'utilities' => {
            key: 'vaco5655[0].#subform[0].Field48[0]',
            question_num: 20
          },
          'otherLivingExpenses' => {
            'name' => {
              key: 'vaco5655[0].#subform[0].Field35[1]'
            },
            'amount' => {
              key: 'vaco5655[0].#subform[0].Field49[0]',
              question_num: 21
            }
          },
          'expensesInstallmentContractsAndOtherDebts' => {
            key: 'vaco5655[0].#subform[0].Field50[0]',
            question_num: 22
          },
          'totalMonthlyExpenses' => {
            key: 'vaco5655[0].#subform[0].Field51[0]',
            question_num: 23
          }
        },
        'discretionaryIncome' => {
          'netMonthlyIncomeLessExpenses' => {
            key: 'vaco5655[0].#subform[0].Field52[0]',
            question_num: 24,
            question_suffix: 'A'
          },
          'amountCanBePaidTowardDebt' => {
            key: 'vaco5655[0].#subform[0].Field53[0]',
            question_num: 24,
            question_suffix: 'B'
          }
        },
        'assets' => {
          'cashInBank' => {
            key: 'vaco5655[0].#subform[1].Field54[0]',
            question_num: 25
          },
          'cashOnHand' => {
            key: 'vaco5655[0].#subform[1].Field55[0]',
            question_num: 26
          },
          'automobiles' => {
            limit: 3,
            question_num: 27,
            'make' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{56 + (i * 4)}[0]" },
              question_num: 27,
              question_text: 'Car make'
            },
            'year' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{57 + (i * 4)}[0]" },
              question_num: 27,
              question_text: 'Car year'
            },
            'model' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{58 + (i * 4)}[0]" },
              question_num: 27,
              question_text: 'Car model'
            },
            'resaleValue' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{59 + (i * 4)}[0]" },
              question_num: 27,
              question_text: 'Car value'
            }
          },
          'trailersBoatsCampers' => {
            key: 'vaco5655[0].#subform[1].Field68[0]',
            question_num: 28
          },
          'usSavingsBonds' => {
            key: 'vaco5655[0].#subform[1].Field69[0]',
            question_num: 29
          },
          'stocksAndOtherBonds' => {
            key: 'vaco5655[0].#subform[1].Field70[0]',
            question_num: 30
          },
          'realEstateOwned' => {
            key: 'vaco5655[0].#subform[1].Field71[0]',
            question_num: 31
          },
          'otherAssets' => {
            limit: 3,
            question_num: 32,
            'name' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{72 + (i * 2)}[0]" }
            },
            'amount' => {
              key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{73 + (i * 2)}[0]" }
            }
          },
          'totalAssets' => {
            key: 'vaco5655[0].#subform[1].Field78[0]'
          }
        },
        'installmentContractsAndOtherDebts' => {
          limit: 8,
          'nameAndAddress' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{79 + (i * 6)}[0]" },
            question_suffix: 'A'
          },
          'dateAndPurpose' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{80 + (i * 6)}[0]" },
            question_suffix: 'B'
          },
          'originalAmount' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{81 + (i * 6)}[0]" },
            question_suffix: 'C'
          },
          'unpaidBalance' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{82 + (i * 6)}[0]" },
            question_suffix: 'D'
          },
          'amountDueMonthly' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{83 + (i * 6)}[0]" },
            question_suffix: 'E'
          },
          'amountPastDue' => {
            key_from_iterator: ->(i) { "vaco5655[0].#subform[1].Field#{84 + (i * 6)}[0]" },
            question_suffix: 'F'
          }
        },
        'totalOfInstallmentContractsAndOtherDebts' => {
          'originalAmount' => {
            key: 'vaco5655[0].#subform[1].Field127[0]'
          },
          'unpaidBalance' => {
            key: 'vaco5655[0].#subform[1].Field128[0]'
          },
          'amountDueMonthly' => {
            key: 'vaco5655[0].#subform[1].Field129[0]'
          },
          'amountPastDue' => {
            key: 'vaco5655[0].#subform[1].Field130[0]'
          }
        },
        'additionalData' => {
          'bankruptcy' => {
            'hasBeenAdjudicatedBankrupt' => {
              key: 'vaco5655[0].#subform[1].RadioButtonList[1]',
              question_num: 35,
              question_suffix: 'A'
            },
            'dateDischarged' => {
              key: 'vaco5655[0].#subform[1].Field133[0]',
              question_num: 35,
              question_suffix: 'B'
            },
            'courtLocation' => {
              key: 'vaco5655[0].#subform[1].Field134[0]',
              question_num: 35,
              question_suffix: 'C'
            },
            'docketNumber' => {
              key: 'vaco5655[0].#subform[1].Field135[0]',
              question_num: 35,
              question_suffix: 'D'
            }
          },
          'additionalComments' => {
            key: 'vaco5655[0].#subform[1].Field136[0]',
            question_num: 36,
            question_text: 'Additional Comments',
            limit: 450
          }
        },
        'applicantCertifications' => {
          'veteranSignature' => {
            key: 'Text1',
            question_num: 37,
            question_suffix: 'A'
          },
          'veteranDateSigned' => {
            key: 'Text3',
            question_num: 37,
            question_suffix: 'B'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        merge_full_name
        merge_veteran_address
        merge_booleans
        merge_ages_of_other_dependents
        merge_employment_history
        merge_income
        merge_debts
        @form_data
      end

      private

      def merge_full_name
        full_name = @form_data['personalData']['veteranFullName']
        spouse_full_name = @form_data['personalData']['spouseFullName']
        @form_data['personalData']['veteranFullName'] = full_name.values_at('first', 'middle', 'last').join(' ')
        if spouse_full_name.present?
          @form_data['personalData']['spouseFullName'] =
            spouse_full_name.values_at('first', 'middle', 'last').join(' ')
        end
      end

      def merge_veteran_address
        @form_data['personalData']['address'] = merge_address(@form_data['personalData']['address'])
      end

      def merge_booleans
        @form_data['personalData']['married'] = @form_data['personalData']['married'] ? 0 : 1
        @form_data['additionalData']['bankruptcy']['hasBeenAdjudicatedBankrupt'] =
          @form_data['additionalData']['bankruptcy']['hasBeenAdjudicatedBankrupt'] ? 0 : 1
      end

      def merge_ages_of_other_dependents
        @form_data['personalData']['agesOfOtherDependents'] =
          @form_data['personalData']['agesOfOtherDependents']&.join(', ') || ''
      end

      def merge_employment_history
        @form_data['personalData']['employmentHistory'].map do |employment|
          # Account for boolean or string JSON val
          is_present = employment['present'].to_s.downcase == 'true'

          merge_value = {
            'kindOfJob' => employment['occupationName'],
            'fromDate' => employment['from'],
            'employerName' => merge_name_and_address(employment, 'employer')
          }

          merge_value['toDate'] = employment['to'] unless is_present

          prefix = "#{employment['veteranOrSpouse'].downcase}#{is_present ? 'Current' : 'Past'}"

          @form_data['personalData'].merge!({ "#{prefix}Employment" => merge_value })
        end
      end

      def merge_name_and_address(record, prefix)
        address = merge_address(record["#{prefix}Address"])
        "#{record["#{prefix}Name"]}  #{address}"
      end

      def merge_address(address_key)
        address_fields = %w[
          addresslineOne
          addresslineTwo
          addresslineThree
          city
          stateOrProvince
          zipOrPostalCode
          countryName
        ]

        address_key.values_at(*address_fields).reject(&:empty?).join(', ')
      end

      def merge_income
        vet_income = @form_data['income']&.find { |i| veteran?(i) }
        spouse_income = @form_data['income']&.find { |i| !veteran?(i) }

        @form_data['veteranIncome'] = vet_income
        @form_data['spouseIncome'] = spouse_income
      end

      def merge_debts
        @form_data['installmentContractsAndOtherDebts']&.map do |debt|
          debt['nameAndAddress'] = merge_name_and_address(debt, 'creditor')
          debt['dateAndPurpose'] = "#{debt['dateStarted']} #{debt['purpose']}"
        end
      end

      def veteran?(obj)
        obj['veteranOrSpouse'] == 'VETERAN'
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
