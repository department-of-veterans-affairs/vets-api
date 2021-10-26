# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'string_helpers'

# rubocop:disable Metrics/ClassLength

module PdfFill
  module Forms
    class Va21p527ez < FormBase
      ITERATOR = PdfFill::HashConverter::ITERATOR
      INCOME_TYPES_KEY = {
        'bank' => 'CASH/NON-INTEREST BEARING BANK ACCOUNTS',
        'interestBank' => 'INTEREST-BEARING BANK ACCOUNTS',
        'ira' => "IRA'S, KEOGH PLANS, ETC.",
        'stocks' => 'STOCKS, BONDS, MUTUAL FUNDS, ETC.',
        'realProperty' => 'REAL PROPERTY',
        'socialSecurity' => 'SOCIAL SECURITY',
        'civilService' => 'U.S. CIVIL SERVICE',
        'railroad' => 'U.S. RAILROAD RETIREMENT',
        'blackLung' => 'BLACK LUNG BENEFITS',
        'serviceRetirement' => 'SERVICE RETIREMENT',
        'ssi' => 'SUPPLEMENTAL SECURITY INCOME (SSI)/PUBLIC ASSISTANCE',
        'salary' => 'GROSS WAGES AND SALARY',
        'interest' => 'TOTAL DIVIDENDS AND INTEREST'
      }.freeze
      # rubocop:disable Metrics/BlockLength
      KEY = lambda do
        key = {
          'vaFileNumber' => { key: 'F[0].Page_5[0].VAfilenumber[0]' },
          'spouseSocialSecurityNumber' => { key: 'F[0].Page_6[0].SSN[0]' },
          'genderMale' => { key: 'F[0].Page_5[0].Male[0]' },
          'genderFemale' => { key: 'F[0].Page_5[0].Female[0]' },
          'hasFileNumber' => { key: 'F[0].Page_5[0].YesFiled[0]' },
          'noFileNumber' => { key: 'F[0].Page_5[0].NoFiled[0]' },
          'hasPowDateRange' => { key: 'F[0].Page_5[0].YesPOW[0]' },
          'noPowDateRange' => { key: 'F[0].Page_5[0].NoPOW[0]' },
          'signature' => {
            key: 'F[0].Page_8[0].Signature[2]',
            limit: 55,
            question_num: 33,
            question_suffix: 'A',
            question_text: "VETERAN'S SIGNATURE"
          },
          'signatureDate' => {
            key: 'F[0].Page_8[0].Date[0]',
            limit: 11,
            question_num: 33,
            question_suffix: 'B',
            question_text: 'DATE SIGNED',
            format: 'date'
          },
          'monthlySpousePayment' => {
            key: 'F[0].Page_6[0].MonthlySupport[0]',
            limit: 11,
            question_num: 22,
            question_suffix: 'H',
            dollar: true,
            question_text: "HOW MUCH DO YOU CONTRIBUTE MONTHLY TO YOUR SPOUSE'S SUPPORT?"
          },
          'spouseDateOfBirth' => {
            key: 'F[0].Page_6[0].Date[8]',
            format: 'date'
          },
          'noLiveWithSpouse' => { key: 'F[0].Page_6[0].CheckboxSpouseNo[0]' },
          'hasLiveWithSpouse' => { key: 'F[0].Page_6[0].CheckboxSpouseYes[0]' },
          'noSpouseIsVeteran' => { key: 'F[0].Page_6[0].CheckboxVetNo[0]' },
          'hasSpouseIsVeteran' => { key: 'F[0].Page_6[0].CheckboxVetYes[0]' },
          'maritalStatusNeverMarried' => {
            key: 'F[0].Page_6[0].CheckboxMaritalNeverMarried[0]'
          },
          'maritalStatusWidowed' => { key: 'F[0].Page_6[0].CheckboxMaritalWidowed[0]' },
          'maritalStatusDivorced' => { key: 'F[0].Page_6[0].CheckboxMaritalDivorced[0]' },
          'maritalStatusMarried' => { key: 'F[0].Page_6[0].CheckboxMaritalMarried[0]' },
          'hasChecking' => { key: 'F[0].Page_8[0].Account[2]' },
          'hasSavings' => { key: 'F[0].Page_8[0].Account[0]' },
          'checkingAccountNumber' => {
            limit: 11,
            question_num: 29,
            question_text: 'Checking Account Number',
            key: 'F[0].Page_8[0].CheckingAccountNumber[0]'
          },
          'noRapidProcessing' => { key: 'F[0].Page_8[0].CheckBox1[0]' },
          'savingsAccountNumber' => {
            limit: 11,
            question_num: 29,
            question_text: 'Savings Account Number',
            key: 'F[0].Page_8[0].SavingsAccountNumber[0]'
          },
          'bankAccount' => {
            'bankName' => {
              limit: 44,
              question_num: 30,
              question_text: 'NAME OF FINANCIAL INSTITUTION',
              key: 'F[0].Page_8[0].Nameofbank[0]'
            },
            'routingNumber' => { key: 'F[0].Page_8[0].Routingortransitnumber[0]' }
          },
          'noBankAccount' => { key: 'F[0].Page_8[0].Account[1]' },
          'otherExpenses' => {
            limit: 4,
            first_key: 'purpose',
            'amount' => {
              limit: 10,
              question_num: 28,
              question_text: 'AMOUNT PAID BY YOU',
              dollar: true,
              key: 'otherExpenses.amount[%iterator%]'
            },
            'purpose' => {
              limit: 58,
              question_num: 28,
              question_text: 'PURPOSE',
              key: 'otherExpenses.purpose[%iterator%]'
            },
            'paidTo' => {
              question_num: 28,
              question_text: 'PAID TO',
              limit: 29,
              key: 'otherExpenses.paidTo[%iterator%]'
            },
            'relationship' => {
              limit: 33,
              question_num: 28,
              question_text: 'RELATIONSHIP OF PERSON FOR WHOM EXPENSES PAID',
              key: 'otherExpenses.relationship[%iterator%]'
            },
            'date' => {
              question_num: 28,
              question_text: 'DATE PAID',
              key: 'otherExpenses.date[%iterator%]',
              format: 'date'
            }
          },
          'hasPreviousNames' => { key: 'F[0].Page_5[0].YesName[0]' },
          'noPreviousNames' => { key: 'F[0].Page_5[0].NameNo[0]' },
          'hasCombatSince911' => { key: 'F[0].Page_5[0].YesCZ[0]' },
          'noCombatSince911' => { key: 'F[0].Page_5[0].NoCZ[0]' },
          'hasSeverancePay' => { key: 'F[0].Page_5[0].YesSep[0]' },
          'noSeverancePay' => { key: 'F[0].Page_5[0].NoSep[0]' },
          'veteranDateOfBirth' => {
            key: 'F[0].Page_5[0].Date[0]',
            format: 'date'
          },
          'spouseVaFileNumber' => { key: 'F[0].Page_6[0].SpouseVAfilenumber[0]' },
          'veteranSocialSecurityNumber' => { key: 'F[0].Page_5[0].SSN[0]' },
          'severancePay' => {
            'amount' => {
              key: 'F[0].Page_5[0].Listamount[0]',
              limit: 17,
              question_num: 16,
              question_suffix: 'B',
              dollar: true,
              question_text: 'LIST AMOUNT (If known)'
            },
            'type' => { key: 'F[0].Page_5[0].Listtype[0]' }
          },
          'vamcTreatmentCenters' => {
            limit: 2,
            first_key: 'location',
            'location' => {
              limit: 46,
              question_num: 10,
              question_suffix: 'A',
              question_text: \
                'LIST ANY VA MEDICAL CENTERS WHERE YOU RECEIVED TREATMENT FOR YOUR CLAIMED DISABILITY(IES)',
              key: "vaHospitalTreatments.nameAndLocation[#{ITERATOR}]"
            }
          },
          'marriageCount' => { key: 'F[0].Page_6[0].Howmanytimesmarried[0]' },
          'spouseMarriageCount' => { key: 'F[0].Page_6[0].Howmanytimesspousemarried[0]' },
          'powDateRangeStart' => {
            key: 'F[0].Page_5[0].Date[1]',
            format: 'date'
          },
          'powDateRangeEnd' => {
            key: 'F[0].Page_5[0].Date[2]',
            format: 'date'
          },
          'jobs' => {
            first_key: 'nameAndAddr',
            limit: 2,
            'annualEarnings' => {
              limit: 10,
              question_num: 17,
              question_suffix: 'F',
              dollar: true,
              question_text: 'WHAT WERE YOUR TOTAL ANNUAL EARNINGS?',
              key: "jobs.annualEarnings[#{ITERATOR}]"
            },
            'nameAndAddr' => {
              key: "jobs.nameAndAddr[#{ITERATOR}]",
              limit: 27,
              question_num: 17,
              question_suffix: 'A',
              question_text: 'WHAT WAS THE NAME AND ADDRESS OF YOUR EMPLOYER?'
            },
            'jobTitle' => {
              key: "jobs.jobTitle[#{ITERATOR}]",
              question_num: 17,
              question_suffix: 'B',
              question_text: 'WHAT WAS YOUR JOB TITLE?',
              limit: 25
            },
            'dateRangeStart' => {
              key: "jobs.dateRangeStart[#{ITERATOR}]",
              question_num: 17,
              question_suffix: 'C',
              question_text: 'WHEN DID YOUR JOB BEGIN?',
              format: 'date'
            },
            'dateRangeEnd' => {
              key: "jobs.dateRangeEnd[#{ITERATOR}]",
              question_num: 17,
              question_suffix: 'D',
              question_text: 'WHEN DID YOUR JOB END?',
              format: 'date'
            },
            'daysMissed' => {
              limit: 9,
              question_num: 17,
              question_suffix: 'E',
              question_text: 'HOW MANY DAYS WERE LOST DUE TO DISABILITY?',
              key: "jobs.daysMissed[#{ITERATOR}]"
            }
          },
          'nationalGuard' => {
            'nameAndAddr' => {
              key: 'F[0].Page_5[0].Nameandaddressofunit[0]',
              limit: 59,
              question_num: 14,
              question_suffix: 'A',
              question_text: 'WHAT IS THE NAME AND ADDRESS OF YOUR RESERVE/NATIONAL GUARD UNIT?'
            },
            'phone' => { key: 'F[0].Page_5[0].Unittelephonenumber[0]' },
            'date' => {
              key: 'F[0].Page_5[0].DateofActivation[0]',
              format: 'date'
            },
            'phoneAreaCode' => { key: 'F[0].Page_5[0].Unittelephoneareacode[0]' }
          },
          'spouseAddress' => {
            limit: 47,
            question_num: 22,
            question_suffix: 'F',
            question_text: "WHAT IS YOUR SPOUSE'S ADDRESS?",
            key: 'F[0].Page_6[0].Spouseaddress[0]'
          },
          'outsideChildren' => {
            limit: 3,
            first_key: 'fullName',
            'childAddress' => {
              limit: 52,
              question_num: 24,
              question_suffix: 'B',
              question_text: "CHILD'S COMPLETE ADDRESS",
              key: 'outsideChildren.childAddress[%iterator%]'
            },
            'fullName' => {
              limit: 48,
              question_num: 24,
              question_suffix: 'A',
              question_text: 'NAME OF DEPENDENT CHILD',
              key: 'outsideChildren.childFullName[%iterator%]'
            },
            'monthlyPayment' => {
              limit: 13,
              question_num: 24,
              question_suffix: 'D',
              dollar: true,
              question_text: "MONTHLY AMOUNT YOU CONTRIBUTE TO THE CHILD'S SUPPORT",
              key: 'outsideChildren.monthlyPayment[%iterator%]'
            },
            'personWhoLivesWithChild' => {
              limit: 40,
              question_num: 24,
              question_suffix: 'C',
              question_text: 'NAME OF PERSON THE CHILD LIVES WITH',
              key: 'outsideChildren.personWhoLivesWithChild[%iterator%]'
            }
          },
          'children' => {
            limit: 3,
            first_key: 'fullName',
            'childSocialSecurityNumber' => {
              question_num: 23,
              question_suffix: 'C',
              question_text: 'SOCIAL SECURITY NUMBER',
              key: 'children.childSocialSecurityNumber[%iterator%]'
            },
            'childDateOfBirth' => {
              question_num: 23,
              question_suffix: 'B',
              question_text: 'DATE OF BIRTH',
              key: 'children.childDateOfBirth[%iterator%]',
              format: 'date'
            },
            'childPlaceOfBirth' => {
              limit: 12,
              question_num: 23,
              question_suffix: 'B',
              question_text: 'PLACE OF BIRTH',
              key: 'children.childPlaceOfBirth[%iterator%]'
            },
            'attendingCollege' => {
              question_num: 23,
              question_suffix: 'G',
              question_text: '18-23 YEARS OLD (in school)',
              key: 'children.attendingCollege[%iterator%]'
            },
            'married' => {
              question_num: 23,
              question_suffix: 'I',
              question_text: 'CHILD MARRIED',
              key: 'children.married[%iterator%]'
            },
            'disabled' => {
              question_num: 23,
              question_suffix: 'H',
              question_text: 'SERIOUSLY DISABLED',
              key: 'children.disabled[%iterator%]'
            },
            'biological' => {
              question_num: 23,
              question_suffix: 'D',
              question_text: 'BIOLOGICAL',
              key: 'children.biological[%iterator%]'
            },
            'fullName' => {
              key: 'children.name[%iterator%]',
              limit: 34,
              question_num: 23,
              question_suffix: 'A',
              question_text: 'NAME OF DEPENDENT CHILD'
            },
            'adopted' => {
              question_num: 23,
              question_suffix: 'E',
              question_text: 'ADOPTED',
              key: 'children.adopted[%iterator%]'
            },
            'stepchild' => {
              question_num: 23,
              question_suffix: 'F',
              question_text: 'STEPCHILD',
              key: 'children.stepchild[%iterator%]'
            },
            'previouslyMarried' => {
              question_num: 23,
              question_suffix: 'J',
              question_text: 'CHILD PREVIOUSLY MARRIED',
              key: 'children.previouslyMarried[%iterator%]'
            }
          },
          'hasNationalGuardActivation' => { key: 'F[0].Page_5[0].YesAD[0]' },
          'noNationalGuardActivation' => { key: 'F[0].Page_5[0].NoAD[0]' },
          'nightPhone' => { key: 'F[0].Page_5[0].Eveningphonenumber[0]' },
          'mobilePhone' => { key: 'F[0].Page_5[0].Cellphonenumber[0]' },
          'mobilePhoneAreaCode' => { key: 'F[0].Page_5[0].Cellphoneareacode[0]' },
          'nightPhoneAreaCode' => { key: 'F[0].Page_5[0].Eveningareacode[0]' },
          'dayPhone' => { key: 'F[0].Page_5[0].Daytimephonenumber[0]' },
          'previousNames' => {
            key: 'F[0].Page_5[0].Listothernames[0]',
            limit: 53,
            question_num: 11,
            question_suffix: 'B',
            question_text: 'PLEASE LIST THE OTHER NAME(S) YOU SERVED UNDER'
          },
          'dayPhoneAreaCode' => { key: 'F[0].Page_5[0].Daytimeareacode[0]' },
          'servicePeriods' => {
            limit: 1,
            first_key: 'serviceBranch',
            'serviceBranch' => {
              key: 'F[0].Page_5[0].Branchofservice[0]',
              limit: 25,
              question_num: 12,
              question_suffix: 'B',
              question_text: 'BRANCH OF SERVICE'
            },
            'activeServiceDateRangeStart' => {
              question_num: 12,
              question_suffix: 'A',
              question_text: 'I ENTERED ACTIVE SERVICE ON',
              key: 'F[0].Page_5[0].DateEnteredActiveService[0]',
              format: 'date'
            },
            'activeServiceDateRangeEnd' => {
              question_num: 12,
              question_suffix: 'C',
              question_text: 'RELEASE DATE OR ANTICIPATED DATE OF RELEASE FROM ACTIVE SERVICE',
              key: 'F[0].Page_5[0].ReleaseDateorAnticipatedReleaseDate[0]',
              format: 'date'
            }
          },
          'veteranAddressLine1' => {
            key: 'F[0].Page_5[0].Currentaddress[0]',
            limit: 53,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'Street address'
          },
          'email' => {
            key: 'F[0].Page_5[0].Preferredemailaddress[0]',
            limit: 43,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'PREFERRED E-MAIL ADDRESS'
          },
          'altEmail' => {
            key: 'F[0].Page_5[0].Alternateemailaddress[0]',
            limit: 43,
            question_num: 8,
            question_suffix: 'B',
            question_text: 'ALTERNATE E-MAIL ADDRESS'
          },
          'cityState' => {
            key: 'F[0].Page_5[0].Citystatezipcodecountry[0]',
            limit: 53,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'City, State, Zip, Country'
          },
          'placeOfSeparation' => {
            key: 'F[0].Page_5[0].Placeofseparation[0]',
            limit: 41,
            question_num: 12,
            question_suffix: 'E',
            question_text: 'PLACE OF LAST OR ANTICIPATED SEPARATION'
          },
          'reasonForNotLivingWithSpouse' => {
            limit: 47,
            question_num: 22,
            question_suffix: 'G',
            question_text: 'TELL US THE REASON WHY YOU ARE NOT LIVING WITH YOUR SPOUSE',
            key: 'F[0].Page_6[0].Reasonfornotlivingwithspouse[0]'
          },
          'disabilities' => {
            limit: 2,
            first_key: 'name',
            'name' => {
              key: "disabilities.name[#{ITERATOR}]",
              limit: 44,
              question_num: 9,
              question_suffix: 'A',
              question_text: 'DISABILITY(IES)'
            },
            'disabilityStartDate' => {
              key: "disabilities.disabilityStartDate[#{ITERATOR}]",
              question_num: 9,
              question_suffix: 'B',
              question_text: 'DATE DISABILITY(IES) BEGAN',
              format: 'date'
            }
          },
          'veteranFullName' => {
            limit: 30,
            question_num: 1,
            question_text: "VETERAN'S NAME",
            key: 'F[0].Page_5[0].Veteransname[0]'
          }
        }

        %w[netWorths monthlyIncomes expectedIncomes].each_with_index do |acct_type, i|
          question_num = 25 + i
          key[acct_type] = {
            first_key: 'recipient',
            'amount' => {
              limit: 12,
              key: "#{acct_type}.amount[#{ITERATOR}]"
            },
            'additionalSourceName' => {
              limit: 14,
              key: "#{acct_type}.additionalSourceName[#{ITERATOR}]"
            },
            'sourceAndAmount' => {
              question_text: 'Source and Amount'
            },
            'recipient' => {
              limit: 34,
              question_text: 'Recipient',
              key: "#{acct_type}.recipient[#{ITERATOR}]"
            }
          }
          key[acct_type].each_value do |v|
            v[:question_num] = question_num if v.is_a?(Hash)
          end

          key[acct_type][:limit] =
            case acct_type
            when 'netWorths'
              8
            when 'monthlyIncomes'
              10
            else
              6
            end
        end

        %w[m spouseM].each do |prefix|
          sub_key = "#{prefix}arriages"
          question_num = prefix == 'm' ? 19 : 21

          key[sub_key] = {
            limit: 2,
            first_key: 'locationOfMarriage',
            'dateOfMarriage' => {
              question_suffix: 'A',
              question_text: 'Date of Marriage',
              key: "#{sub_key}.dateOfMarriage[#{ITERATOR}]",
              format: 'date'
            },
            'otherExplanations' => {
              limit: 90,
              skip_index: true,
              question_suffix: 'F',
              question_text: "IF YOU INDICATED \"OTHER\" AS TYPE OF MARRIAGE IN ITEM #{question_num}C, PLEASE EXPLAIN",
              key: "F[0].Page_6[0].Explainothertype#{prefix == 'm' ? 's' : ''}ofmarriage[0]"
            },
            'locationOfMarriage' => {
              limit: 22,
              question_text: 'PLACE OF MARRIAGE',
              question_suffix: 'A',
              key: "#{sub_key}.locationOfMarriage[#{ITERATOR}]"
            },
            'locationOfSeparation' => {
              limit: 13,
              question_text: 'PLACE MARRIAGE TERMINATED',
              question_suffix: 'E',
              key: "#{sub_key}.locationOfSeparation[#{ITERATOR}]"
            },
            'spouseFullName' => {
              limit: 27,
              question_text: 'TO WHOM MARRIED',
              question_suffix: 'B',
              key: "#{sub_key}.spouseFullName[#{ITERATOR}]"
            },
            'marriageType' => {
              limit: 27,
              question_text: 'TYPE OF MARRIAGE',
              question_suffix: 'C',
              key: "#{sub_key}.marriageType[#{ITERATOR}]"
            },
            'dateOfSeparation' => {
              question_text: 'DATE MARRIAGE TERMINATED',
              question_suffix: 'E',
              key: "#{sub_key}.dateOfSeparation[#{ITERATOR}]",
              format: 'date'
            },
            'reasonForSeparation' => {
              limit: 33,
              question_text: 'HOW MARRIAGE TERMINATED',
              question_suffix: 'D',
              key: "#{sub_key}.reasonForSeparation[#{ITERATOR}]"
            }
          }

          key[sub_key].each_value do |v|
            v[:question_num] = question_num if v.is_a?(Hash)
          end
        end

        key
      end.call.freeze
      # rubocop:enable Metrics/BlockLength

      DEFAULT_FINANCIAL_ACCT = { 'name' => 'None', 'amount' => 0, 'recipient' => 'None' }.freeze

      def expand_pow_date_range(pow_date_range)
        expand_checkbox(pow_date_range.present?, 'PowDateRange')
      end

      def expand_va_file_number(va_file_number)
        expand_checkbox(va_file_number.present?, 'FileNumber')
      end

      def expand_previous_names(previous_names)
        expand_checkbox(previous_names.present?, 'PreviousNames')
      end

      def expand_severance_pay(severance_pay)
        amount = severance_pay.try(:[], 'amount') || 0

        expand_checkbox(amount.positive?, 'SeverancePay')
      end

      def expand_chk_and_del_key(hash, key, new_key = nil)
        new_key = StringHelpers.capitalize_only(key) if new_key.nil?
        val = hash[key]
        hash.delete(key)

        expand_checkbox(val, new_key)
      end

      def combine_address(address)
        return if address.blank?

        combine_hash(address, %w[street street2], ', ')
      end

      def combine_city_state(address)
        return if address.blank?

        city_state_fields = %w[city state postalCode country]

        combine_hash(address, city_state_fields, ', ')
      end

      def split_phone(phone)
        return [nil, nil] if phone.blank?

        [phone[0..2], phone[3..]]
      end

      def expand_gender(gender)
        return {} if gender.blank?

        {
          'genderMale' => gender == 'M',
          'genderFemale' => gender == 'F'
        }
      end

      def expand_jobs(jobs)
        return if jobs.blank?

        jobs.each do |job|
          combine_name_addr(job, name_key: 'employer')

          expand_date_range(job, 'dateRange')
        end
      end

      def replace_phone(hash, key)
        return if hash.try(:[], key).blank?

        phone_arr = split_phone(hash[key])
        hash["#{key}AreaCode"] = phone_arr[0]
        hash[key] = phone_arr[1]

        hash
      end

      def expand_marital_status(hash, key)
        marital_status = hash[key]
        return if marital_status.blank?

        [
          'Married',
          'Never Married',
          'Separated',
          'Widowed',
          'Divorced'
        ].each do |status|
          if marital_status == status
            hash["maritalStatus#{status.tr(' ', '_').camelize}"] = true
            break
          end
        end

        hash
      end

      def split_children(children)
        children_split = {
          outside: [],
          cohabiting: []
        }

        children.each do |child|
          children_split[child['childInHousehold'] ? :cohabiting : :outside] << child
        end

        children_split
      end

      def expand_dependents
        @form_data['dependents']&.each do |dependent|
          dependent['fullName'] = combine_full_name(dependent['fullName'])
        end

        expand_children(@form_data, 'dependents')
      end

      def expand_children(hash, key)
        children = hash[key]
        return if children.blank?

        children.each do |child|
          child['personWhoLivesWithChild'] = combine_full_name(child['personWhoLivesWithChild'])

          child['childRelationship'].tap do |child_rel|
            next if child_rel.blank?

            child[child_rel] = true
          end

          combine_both_addr(child, 'childAddress')
        end

        children_split = split_children(children)

        hash['children'] = children
        hash['outsideChildren'] = children_split[:outside]

        hash
      end

      def expand_marriages(hash, key)
        marriages = hash[key]
        return if marriages.blank?

        other_explanations = []

        marriages.each do |marriage|
          marriage['spouseFullName'] = combine_full_name(marriage['spouseFullName'])
          marriage['reasonForSeparation'] ||= 'Marriage has not been terminated'
          other_explanations << marriage['otherExplanation'] if marriage['otherExplanation'].present?
        end

        marriages[0]['otherExplanations'] = other_explanations.join(', ')

        hash
      end

      def expand_additional_sources(recipient, additional_sources, financial_accts)
        additional_sources&.each do |additional_source|
          source = additional_source['name']
          amount = additional_source['amount']

          financial_accts['additionalSources'] << {
            'recipient' => recipient,
            'amount' => amount,
            'sourceAndAmount' => "#{source.humanize}: $#{amount}",
            'additionalSourceName' => source
          }
        end
      end

      def expand_financial_acct(recipient, financial_acct, financial_accts)
        return if financial_acct.blank?

        financial_accts.each do |income_type, financial_accts_for_type|
          next if income_type == 'additionalSources'

          amount = financial_acct[income_type]
          next if amount.nil?

          source = INCOME_TYPES_KEY[income_type]

          financial_accts_for_type << {
            'recipient' => recipient,
            'sourceAndAmount' => "#{source.humanize}: $#{amount}",
            'amount' => amount
          }
        end

        expand_additional_sources(recipient, financial_acct['additionalSources'], financial_accts)

        financial_accts
      end

      def unfilled_multiline_acct?(acct_type, accts)
        %w[socialSecurity salary].include?(acct_type) && accts.size < 2
      end

      def zero_financial_accts(financial_accts)
        financial_accts.each do |acct_type, accts|
          accts << DEFAULT_FINANCIAL_ACCT if accts.blank?
          accts << DEFAULT_FINANCIAL_ACCT if unfilled_multiline_acct?(acct_type, accts)
        end

        financial_accts
      end

      def expand_financial_accts(definition)
        financial_accts = {}
        VetsJsonSchema::SCHEMAS['21P-527EZ']['definitions'][definition]['properties'].each_key do |acct_type|
          financial_accts[acct_type] = []
        end

        %w[myself spouse].each do |person|
          expected_income = @form_data[
            person == 'myself' ? definition : "spouse#{StringHelpers.capitalize_only(definition)}"
          ]
          expand_financial_acct(person.capitalize, expected_income, financial_accts)
        end

        dependents = @form_data['dependents'] || []

        dependents.each do |dependent|
          expand_financial_acct(dependent['fullName'], dependent[definition], financial_accts)
        end

        zero_financial_accts(financial_accts)
      end

      def expand_monthly_incomes
        financial_accts = expand_financial_accts('monthlyIncome')
        fill_financial_blanks(KEY['monthlyIncomes'][:limit], financial_accts)

        monthly_incomes = []
        10.times { monthly_incomes << {} }

        monthly_incomes[0] = financial_accts['socialSecurity'][0]
        monthly_incomes[1] = financial_accts['socialSecurity'][1]

        %w[civilService railroad blackLung serviceRetirement ssi].each_with_index do |acct_type, i|
          i += 2
          monthly_incomes[i] = financial_accts[acct_type][0]
        end

        (7..9).each_with_index do |i, j|
          monthly_incomes[i] = financial_accts['additionalSources'][j]
        end

        overflow_financial_accts(monthly_incomes, financial_accts)
        @form_data['monthlyIncomes'] = monthly_incomes
      end

      def fill_financial_blanks(limit, financial_accts)
        padding = limit - financial_accts.except('additionalSources').size - financial_accts['additionalSources'].size
        additional = Array.new(padding) { |_| DEFAULT_FINANCIAL_ACCT }
        expand_additional_sources('None', additional, financial_accts)
        financial_accts
      end

      def overflow_financial_accts(financial_accts, all_financial_accts)
        all_financial_accts.each_value do |arr|
          arr.each do |financial_acct|
            financial_accts << financial_acct unless financial_accts.include?(financial_acct)
          end
        end
      end

      def expand_net_worths
        financial_accts = expand_financial_accts('netWorth')

        net_worths = []
        8.times do
          net_worths << {}
        end

        %w[bank interestBank ira stocks realProperty].each_with_index do |acct_type, i|
          net_worths[i] = financial_accts[acct_type][0]
        end
        [5, 6].each { |i| net_worths[i] = DEFAULT_FINANCIAL_ACCT }

        if financial_accts['additionalSources'].size < 1
          expand_additional_sources('None', [DEFAULT_FINANCIAL_ACCT], financial_accts)
        end

        net_worths[7] = financial_accts['additionalSources'][0]

        overflow_financial_accts(net_worths, financial_accts)

        @form_data['netWorths'] = net_worths
      end

      def expand_expected_incomes
        financial_accts = expand_financial_accts('expectedIncome')
        fill_financial_blanks(KEY['expectedIncomes'][:limit], financial_accts)

        expected_incomes = []
        6.times do
          expected_incomes << {}
        end

        expected_incomes[0] = financial_accts['salary'][0]
        expected_incomes[1] = financial_accts['salary'][1]
        expected_incomes[2] = financial_accts['interest'][0]
        (3..5).each_with_index do |i, j|
          expected_incomes[i] = financial_accts['additionalSources'][j]
        end

        overflow_financial_accts(expected_incomes, financial_accts)

        @form_data['expectedIncomes'] = expected_incomes
      end

      def expand_bank_acct(bank_account)
        return if bank_account.blank?

        account_type = bank_account['accountType']
        @form_data['hasChecking'] = account_type == 'checking'
        @form_data['hasSavings'] = account_type == 'savings'

        account_number = bank_account['accountNumber']
        @form_data["#{account_type}AccountNumber"] = account_number if account_type.present?

        @form_data
      end

      def combine_other_expenses
        other_expenses = @form_data['otherExpenses'] || []
        other_expenses.each do |other_expense|
          other_expense['relationship'] = 'Myself'
        end

        spouse_other_expenses = @form_data['spouseOtherExpenses']
        spouse_other_expenses&.each do |other_expense|
          other_expense['relationship'] = 'Spouse'
        end
        other_expenses += spouse_other_expenses if spouse_other_expenses.present?

        @form_data['dependents']&.each do |dependent|
          dependent_other_expenses = dependent['otherExpenses']
          if dependent_other_expenses.present?
            dependent_other_expenses.each do |other_expense|
              other_expense['relationship'] = dependent['fullName']
            end

            other_expenses += dependent_other_expenses
          end
        end

        @form_data['otherExpenses'] = other_expenses
      end

      def replace_phone_fields
        %w[nightPhone dayPhone mobilePhone].each do |attr|
          replace_phone(@form_data, attr)
        end
        replace_phone(@form_data['nationalGuard'], 'phone')
      end

      def expand_service_periods
        service_periods = @form_data['servicePeriods']
        return if service_periods.blank?

        service_periods.each do |service_period|
          expand_date_range(service_period, 'activeServiceDateRange')
        end
      end

      def expand_spouse_addr
        combine_both_addr(@form_data, 'spouseAddress')
      end

      # rubocop:disable Metrics/MethodLength
      def merge_fields(_options = {})
        expand_signature(@form_data['veteranFullName'])
        @form_data['veteranFullName'] = combine_full_name(@form_data['veteranFullName'])

        %w[
          gender
          vaFileNumber
          previousNames
          severancePay
          powDateRange
        ].each do |attr|
          @form_data.merge!(public_send("expand_#{attr.underscore}", @form_data[attr]))
        end

        %w[
          nationalGuardActivation
          combatSince911
          spouseIsVeteran
          liveWithSpouse
        ].each do |attr|
          @form_data.merge!(public_send('expand_chk_and_del_key', @form_data, attr))
        end

        replace_phone_fields

        @form_data['cityState'] = combine_city_state(@form_data['veteranAddress'])
        @form_data['veteranAddressLine1'] = combine_address(@form_data['veteranAddress'])
        @form_data.delete('veteranAddress')

        @form_data['previousNames'] = combine_previous_names(@form_data['previousNames'])

        combine_name_addr(@form_data['nationalGuard'])

        expand_jobs(@form_data['jobs'])

        expand_date_range(@form_data, 'powDateRange')

        expand_service_periods
        expand_dependents

        %w[marriages spouseMarriages].each do |marriage_type|
          expand_marriages(@form_data, marriage_type)
        end

        @form_data['spouseMarriageCount'] = @form_data['spouseMarriages']&.length || 0
        @form_data['marriageCount'] = @form_data['marriages']&.length || 0

        expand_spouse_addr

        expand_marital_status(@form_data, 'maritalStatus')

        expand_expected_incomes
        expand_net_worths
        expand_monthly_incomes
        combine_other_expenses

        expand_bank_acct(@form_data['bankAccount'])

        @form_data
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
# rubocop:enable Metrics/ClassLength
