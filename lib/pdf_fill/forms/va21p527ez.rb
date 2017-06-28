# frozen_string_literal: true
# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class VA21P527EZ
      ITERATOR = PdfFill::HashConverter::ITERATOR
      DATE_STRFTIME = '%m/%d/%Y'
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
          'monthlySpousePayment' => {
            key: 'F[0].Page_6[0].MonthlySupport[0]',
            limit: 11,
            question: "22H. HOW MUCH DO YOU CONTRIBUTE MONTHLY TO YOUR SPOUSE'S SUPPORT?"
          },
          'spouseDateOfBirth' => { key: 'F[0].Page_6[0].Date[8]' },
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
            question: '29. Checking Account Number',
            key: 'F[0].Page_8[0].CheckingAccountNumber[0]'
          },
          'noRapidProcessing' => { key: 'F[0].Page_8[0].CheckBox1[0]' },
          'savingsAccountNumber' => {
            limit: 11,
            question: '29. Savings Account Number',
            key: 'F[0].Page_8[0].SavingsAccountNumber[0]'
          },
          'bankAccount' => {
            'bankName' => {
              limit: 44,
              question: '30. NAME OF FINANCIAL INSTITUTION',
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
              question: '28. AMOUNT PAID BY YOU',
              key: 'otherExpenses.amount[%iterator%]'
            },
            'purpose' => {
              limit: 58,
              question: '28. PURPOSE',
              key: 'otherExpenses.purpose[%iterator%]'
            },
            'paidTo' => {
              question: '28. PAID TO',
              limit: 29,
              key: 'otherExpenses.paidTo[%iterator%]'
            },
            'relationship' => {
              limit: 33,
              question: '28. RELATIONSHIP OF PERSON FOR WHOM EXPENSES PAID',
              key: 'otherExpenses.relationship[%iterator%]'
            },
            'date' => {
              question: '28. DATE PAID',
              key: 'otherExpenses.date[%iterator%]'
            }
          },
          'hasPreviousNames' => { key: 'F[0].Page_5[0].YesName[0]' },
          'noPreviousNames' => { key: 'F[0].Page_5[0].NameNo[0]' },
          'hasCombatSince911' => { key: 'F[0].Page_5[0].YesCZ[0]' },
          'noCombatSince911' => { key: 'F[0].Page_5[0].NoCZ[0]' },
          'spouseMarriagesExplanations' => {
            limit: 90,
            question: '21F. IF YOU INDICATED "OTHER" AS TYPE OF MARRIAGE IN ITEM 21C, PLEASE EXPLAIN:',
            key: 'F[0].Page_6[0].Explainothertypeofmarriage[0]'
          },
          'marriagesExplanations' => {
            limit: 90,
            question: '19F. IF YOU INDICATED "OTHER" AS TYPE OF MARRIAGE IN ITEM 19C, PLEASE EXPLAIN:',
            key: 'F[0].Page_6[0].Explainothertypesofmarriage[0]'
          },
          'hasSeverancePay' => { key: 'F[0].Page_5[0].YesSep[0]' },
          'noSeverancePay' => { key: 'F[0].Page_5[0].NoSep[0]' },
          'veteranDateOfBirth' => { key: 'F[0].Page_5[0].Date[0]' },
          'spouseVaFileNumber' => { key: 'F[0].Page_6[0].SpouseVAfilenumber[0]' },
          'veteranSocialSecurityNumber' => { key: 'F[0].Page_5[0].SSN[0]' },
          'severancePay' => {
            'amount' => {
              key: 'F[0].Page_5[0].Listamount[0]',
              limit: 17,
              question: '16B. LIST AMOUNT (If known)'
            },
            'type' => { key: 'F[0].Page_5[0].Listtype[0]' }
          },
          'marriageCount' => { key: 'F[0].Page_6[0].Howmanytimesmarried[0]' },
          'spouseMarriageCount' => { key: 'F[0].Page_6[0].Howmanytimesspousemarried[0]' },
          'powDateRangeStart' => { key: 'F[0].Page_5[0].Date[1]' },
          'powDateRangeEnd' => { key: 'F[0].Page_5[0].Date[2]' },
          'jobs' => {
            first_key: 'nameAndAddr',
            limit: 2,
            'annualEarnings' => {
              limit: 10,
              question: '17F. WHAT WERE YOUR TOTAL ANNUAL EARNINGS?',
              key: "jobs.annualEarnings[#{ITERATOR}]"
            },
            'nameAndAddr' => {
              key: "jobs.nameAndAddr[#{ITERATOR}]",
              limit: 27,
              question: '17A. WHAT WAS THE NAME AND ADDRESS OF YOUR EMPLOYER?'
            },
            'jobTitle' => {
              key: "jobs.jobTitle[#{ITERATOR}]",
              question: '17B. WHAT WAS YOUR JOB TITLE?',
              limit: 25
            },
            'dateRangeStart' => {
              key: "jobs.dateRangeStart[#{ITERATOR}]",
              question: '17C. WHEN DID YOUR JOB BEGIN?'
            },
            'dateRangeEnd' => {
              key: "jobs.dateRangeEnd[#{ITERATOR}]",
              question: '17D. WHEN DID YOUR JOB END?'
            },
            'daysMissed' => {
              limit: 9,
              question: '17E. HOW MANY DAYS WERE LOST DUE TO DISABILITY?',
              key: "jobs.daysMissed[#{ITERATOR}]"
            }
          },
          'nationalGuard' => {
            'nameAndAddr' => {
              key: 'F[0].Page_5[0].Nameandaddressofunit[0]',
              limit: 59,
              question: '14A. WHAT IS THE NAME AND ADDRESS OF YOUR RESERVE/NATIONAL GUARD UNIT?'
            },
            'phone' => { key: 'F[0].Page_5[0].Unittelephonenumber[0]' },
            'date' => { key: 'F[0].Page_5[0].DateofActivation[0]' },
            'phoneAreaCode' => { key: 'F[0].Page_5[0].Unittelephoneareacode[0]' }
          },
          'spouseAddress' => {
            limit: 47,
            question: "22F. WHAT IS YOUR SPOUSE'S ADDRESS?",
            key: 'F[0].Page_6[0].Spouseaddress[0]'
          },
          'outsideChildren' => {
            limit: 3,
            first_key: 'fullName',
            'childAddress' => {
              limit: 52,
              question: "24B. CHILD'S COMPLETE ADDRESS",
              key: 'outsideChildren.childAddress[%iterator%]'
            },
            'fullName' => {
              limit: 48,
              question: '24A. NAME OF DEPENDENT CHILD',
              key: 'outsideChildren.childFullName[%iterator%]'
            },
            'monthlyPayment' => {
              limit: 13,
              question: "24D. MONTHLY AMOUNT YOU CONTRIBUTE TO THE CHILD'S SUPPORT",
              key: 'outsideChildren.monthlyPayment[%iterator%]'
            },
            'personWhoLivesWithChild' => {
              limit: 40,
              question: '24C. NAME OF PERSON THE CHILD LIVES WITH',
              key: 'outsideChildren.personWhoLivesWithChild[%iterator%]'
            }
          },
          'children' => {
            limit: 3,
            first_key: 'fullName',
            'childSocialSecurityNumber' => {
              question: '23C. SOCIAL SECURITY NUMBER',
              key: 'children.childSocialSecurityNumber[%iterator%]'
            },
            'childDateOfBirth' => {
              question: '23B. DATE OF BIRTH',
              key: 'children.childDateOfBirth[%iterator%]'
            },
            'childPlaceOfBirth' => {
              limit: 12,
              question: '23B. PLACE OF BIRTH',
              key: 'children.childPlaceOfBirth[%iterator%]'
            },
            'attendingCollege' => {
              question: '23G. 18-23 YEARS OLD (in school)',
              key: 'children.attendingCollege[%iterator%]'
            },
            'married' => {
              question: '23I. CHILD MARRIED',
              key: 'children.married[%iterator%]'
            },
            'disabled' => {
              question: '23H. SERIOUSLY DISABLED',
              key: 'children.disabled[%iterator%]'
            },
            'biological' => {
              question: '23D. BIOLOGICAL',
              key: 'children.biological[%iterator%]'
            },
            'fullName' => {
              key: 'children.name[%iterator%]',
              limit: 34,
              question: '23A. NAME OF DEPENDENT CHILD'
            },
            'adopted' => {
              question: '23E. ADOPTED',
              key: 'children.adopted[%iterator%]'
            },
            'stepchild' => {
              question: '23F. STEPCHILD',
              key: 'children.stepchild[%iterator%]'
            },
            'previouslyMarried' => {
              question: '23J. CHILD PREVIOUSLY MARRIED',
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
            question: '11B. PLEASE LIST THE OTHER NAME(S) YOU SERVED UNDER'
          },
          'dayPhoneAreaCode' => { key: 'F[0].Page_5[0].Daytimeareacode[0]' },
          'serviceBranch' => {
            key: 'F[0].Page_5[0].Branchofservice[0]',
            limit: 25,
            question: '12B. BRANCH OF SERVICE'
          },
          'veteranAddressLine1' => {
            key: 'F[0].Page_5[0].Currentaddress[0]',
            limit: 53,
            question: '7A. Street address'
          },
          'email' => {
            key: 'F[0].Page_5[0].Preferredemailaddress[0]',
            limit: 43,
            question: '8A. PREFERRED E-MAIL ADDRESS'
          },
          'altEmail' => {
            key: 'F[0].Page_5[0].Alternateemailaddress[0]',
            limit: 43,
            question: '8B. ALTERNATE E-MAIL ADDRESS'
          },
          'cityState' => {
            key: 'F[0].Page_5[0].Citystatezipcodecountry[0]',
            limit: 53,
            question: '7A. City, State, Zip, Country'
          },
          'activeServiceDateRangeStart' => { key: 'F[0].Page_5[0].DateEnteredActiveService[0]' },
          'activeServiceDateRangeEnd' => { key: 'F[0].Page_5[0].ReleaseDateorAnticipatedReleaseDate[0]' },
          'placeOfSeparation' => {
            key: 'F[0].Page_5[0].Placeofseparation[0]',
            limit: 41,
            question: '12E. PLACE OF LAST OR ANTICIPATED SEPARATION'
          },
          'reasonForNotLivingWithSpouse' => {
            limit: 47,
            question: '22G. TELL US THE REASON WHY YOU ARE NOT LIVING WITH YOUR SPOUSE',
            key: 'F[0].Page_6[0].Reasonfornotlivingwithspouse[0]'
          },
          'disabilities' => {
            limit: 2,
            first_key: 'name',
            'name' => {
              key: "disabilities.name[#{ITERATOR}]",
              limit: 44,
              question: '9A. DISABILITY(IES)'
            },
            'disabilityStartDate' => {
              key: "disabilities.disabilityStartDate[#{ITERATOR}]",
              question: '9B. DATE DISABILITY(IES) BEGAN'
            }
          },
          'veteranFullName' => {
            limit: 30,
            question: "1. VETERAN'S NAME",
            key: 'F[0].Page_5[0].Veteransname[0]'
          }
        }

        %w(netWorths monthlyIncomes expectedIncomes).each_with_index do |acct_type, i|
          question_num = 25 + i
          key[acct_type] = {
            first_key: 'recipient',
            'amount' => {
              limit: 12,
              question: "#{question_num}. Amount",
              key: "#{acct_type}.amount[#{ITERATOR}]"
            },
            'source' => {
              question: "#{question_num}. Source"
            },
            'additionalSourceName' => {
              limit: 14,
              question: "#{question_num}. Source",
              key: "#{acct_type}.additionalSourceName[#{ITERATOR}]"
            },
            'recipient' => {
              limit: 34,
              question: "#{question_num}. Recipient",
              key: "#{acct_type}.recipient[#{ITERATOR}]"
            }
          }

          key[acct_type][:limit] =
            if acct_type == 'netWorths'
              8
            elsif acct_type == 'monthlyIncomes'
              10
            else
              6
            end
        end

        %w(m spouseM).each do |prefix|
          sub_key = "#{prefix}arriages"
          question_num = prefix == 'm' ? '19' : '21'

          key[sub_key] = {
            limit: 2,
            first_key: 'locationOfMarriage',
            'dateOfMarriage' => {
              question: "#{question_num}A. Date of Marriage",
              key: "#{sub_key}.dateOfMarriage[#{ITERATOR}]"
            },
            'locationOfMarriage' => {
              limit: 22,
              question: "#{question_num}A. PLACE OF MARRIAGE",
              key: "#{sub_key}.locationOfMarriage[#{ITERATOR}]"
            },
            'locationOfSeparation' => {
              limit: 13,
              question: "#{question_num}E. PLACE MARRIAGE TERMINATED",
              key: "#{sub_key}.locationOfSeparation[#{ITERATOR}]"
            },
            'spouseFullName' => {
              limit: 27,
              question: "#{question_num}B. TO WHOM MARRIED",
              key: "#{sub_key}.spouseFullName[#{ITERATOR}]"
            },
            'marriageType' => {
              limit: 27,
              question: "#{question_num}C. TYPE OF MARRIAGE",
              key: "#{sub_key}.marriageType[#{ITERATOR}]"
            },
            'dateOfSeparation' => {
              question: "#{question_num}E. DATE MARRIAGE TERMINATED",
              key: "#{sub_key}.dateOfSeparation[#{ITERATOR}]"
            },
            'reasonForSeparation' => {
              limit: 33,
              question: "#{question_num}D. HOW MARRIAGE TERMINATED",
              key: "#{sub_key}.reasonForSeparation[#{ITERATOR}]"
            }
          }
        end

        key
      end.call.freeze

      def initialize(form_data)
        @form_data = form_data.deep_dup
      end

      def expand_date_range(hash, key)
        return if hash.blank?
        date_range = hash[key]
        return if date_range.blank?

        hash["#{key}Start"] = date_range['from']
        hash["#{key}End"] = date_range['to']
        hash.delete(key)

        hash
      end

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

      def expand_checkbox(value, key)
        {
          "has#{key}" => value == true,
          "no#{key}" => value == false
        }
      end

      def combine_address(address)
        return if address.blank?

        combine_hash(address, %w(street street2), ', ')
      end

      def combine_full_address(address)
        combine_hash(
          address,
          %w(
            street
            street2
            city
            state
            postalCode
            country
          ),
          ', '
        )
      end

      def combine_city_state(address)
        return if address.blank?

        city_state_fields = %w(city state postalCode country)

        combine_hash(address, city_state_fields, ', ')
      end

      def split_phone(phone)
        return [nil, nil] if phone.blank?

        [phone[0..2], phone[3..-1]]
      end

      def expand_gender(gender)
        return {} if gender.blank?

        {
          'genderMale' => gender == 'M',
          'genderFemale' => gender == 'F'
        }
      end

      def combine_name_addr(hash)
        return if hash.blank?

        hash['address'] = combine_full_address(hash['address'])
        combine_hash_and_del_keys(hash, %w(name address), 'nameAndAddr', ', ')
      end

      def expand_jobs(jobs)
        return if jobs.blank?

        jobs.each do |job|
          job['address'] = combine_full_address(job['address'])
          expand_date_range(job, 'dateRange')
          combine_hash_and_del_keys(job, %w(employer address), 'nameAndAddr', ', ')
        end
      end

      def replace_phone(hash, key)
        return if hash.try(:[], key).blank?
        phone_arr = split_phone(hash[key])
        hash["#{key}AreaCode"] = phone_arr[0]
        hash[key] = phone_arr[1]

        hash
      end

      def combine_hash_and_del_keys(hash, keys, new_key, separator = ' ')
        return if hash.blank?
        hash[new_key] = combine_hash(hash, keys, separator)

        keys.each do |key|
          hash.delete(key)
        end

        hash
      end

      def combine_hash(hash, keys, separator = ' ')
        return if hash.blank?

        combined = []

        keys.each do |key|
          combined << hash[key]
        end

        combined.compact.join(separator)
      end

      def combine_previous_names(previous_names)
        return if previous_names.blank?

        previous_names.map do |previous_name|
          combine_full_name(previous_name)
        end.join(', ')
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
        children = hash[key]&.find_all do |dependent|
          dependent['dependentRelationship'] == 'child'
        end
        return if children.blank?

        children.each do |child|
          child['personWhoLivesWithChild'] = combine_full_name(child['personWhoLivesWithChild'])

          child['childRelationship'].tap do |child_rel|
            next if child_rel.blank?

            child[child_rel] = true
          end

          child['childAddress'] = combine_full_address(child['childAddress'])
        end

        children_split = split_children(children)

        hash['children'] = children_split[:cohabiting]
        hash['outsideChildren'] = children_split[:outside]

        hash
      end

      def combine_full_name(full_name)
        combine_hash(full_name, %w(first middle last suffix))
      end

      def expand_marriages(hash, key)
        marriages = hash[key]
        return if marriages.blank?
        other_explanations = []

        marriages.each do |marriage|
          marriage['spouseFullName'] = combine_full_name(marriage['spouseFullName'])
          other_explanations << marriage['otherExplanation'] if marriage['otherExplanation'].present?
        end

        hash["#{key}Explanations"] = other_explanations.join(', ')

        hash
      end

      def expand_financial_acct(recipient, financial_acct, financial_accts)
        return if financial_acct.blank?

        financial_accts.each do |income_type, financial_accts_for_type|
          next if income_type == 'additionalSources'

          amount = financial_acct[income_type]
          next if amount.nil? || amount.zero?

          financial_accts_for_type << {
            'recipient' => recipient,
            'source' => INCOME_TYPES_KEY[income_type],
            'amount' => amount
          }
        end

        financial_acct['additionalSources']&.each do |additional_source|
          financial_accts['additionalSources'] << {
            'recipient' => recipient,
            'amount' => additional_source['amount'],
            'additionalSourceName' => additional_source['name']
          }
        end

        financial_accts
      end

      def zero_financial_accts(financial_accts)
        financial_accts.each do |acct_type, accts|
          if accts.size.zero? && acct_type != 'additionalSources'
            accts << {
              'recipient' => 'Myself',
              'amount' => 0
            }
          end
        end

        financial_accts
      end

      def expand_financial_accts(definition)
        financial_accts = {}
        VetsJsonSchema::SCHEMAS['21P-527EZ']['definitions'][definition]['properties'].keys.each do |acct_type|
          financial_accts[acct_type] = []
        end

        %w(myself spouse).each do |person|
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

        monthly_incomes = []
        10.times { monthly_incomes << {} }

        monthly_incomes[0] = financial_accts['socialSecurity'][0]
        monthly_incomes[1] = financial_accts['socialSecurity'][1]

        %w(
          civilService
          railroad
          blackLung
          serviceRetirement
          ssi
        ).each_with_index do |acct_type, i|
          i += 2
          monthly_incomes[i] = financial_accts[acct_type][0]
        end

        (7..9).each_with_index do |i, j|
          monthly_incomes[i] = financial_accts['additionalSources'][j]
        end

        overflow_financial_accts(monthly_incomes, financial_accts)

        @form_data['monthlyIncomes'] = monthly_incomes
      end

      def overflow_financial_accts(financial_accts, all_financial_accts)
        all_financial_accts.each do |_, arr|
          arr.each do |financial_acct|
            unless financial_accts.include?(financial_acct)
              financial_accts << financial_acct
            end
          end
        end
      end

      def expand_net_worths
        financial_accts = expand_financial_accts('netWorth')

        net_worths = []
        8.times do
          net_worths << {}
        end

        %w(
          bank
          interestBank
          ira
          stocks
          realProperty
        ).each_with_index do |acct_type, i|
          net_worths[i] = financial_accts[acct_type][0]
        end
        net_worths[7] = financial_accts['additionalSources'][0]

        overflow_financial_accts(net_worths, financial_accts)

        @form_data['netWorths'] = net_worths
      end

      def expand_expected_incomes
        financial_accts = expand_financial_accts('expectedIncome')

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
        if account_type.present?
          @form_data["#{account_type}AccountNumber"] = account_number
        end

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
        %w(nightPhone dayPhone mobilePhone).each do |attr|
          replace_phone(@form_data, attr)
        end
        replace_phone(@form_data['nationalGuard'], 'phone')
      end

      # rubocop:disable Metrics/MethodLength
      def merge_fields
        @form_data['veteranFullName'] = combine_full_name(@form_data['veteranFullName'])

        %w(
          gender
          vaFileNumber
          previousNames
          severancePay
          powDateRange
        ).each do |attr|
          @form_data.merge!(public_send("expand_#{attr.underscore}", @form_data[attr]))
        end

        %w(
          nationalGuardActivation
          combatSince911
          spouseIsVeteran
          liveWithSpouse
        ).each do |attr|
          @form_data.merge!(public_send('expand_chk_and_del_key', @form_data, attr))
        end

        replace_phone_fields

        @form_data['cityState'] = combine_city_state(@form_data['veteranAddress'])
        @form_data['veteranAddressLine1'] = combine_address(@form_data['veteranAddress'])
        @form_data.delete('veteranAddress')

        @form_data['previousNames'] = combine_previous_names(@form_data['previousNames'])

        combine_name_addr(@form_data['nationalGuard'])

        expand_jobs(@form_data['jobs'])

        %w(activeServiceDateRange powDateRange).each do |attr|
          expand_date_range(@form_data, attr)
        end

        expand_dependents

        %w(marriages spouseMarriages).each do |marriage_type|
          expand_marriages(@form_data, marriage_type)
        end

        @form_data['spouseMarriageCount'] = @form_data['spouseMarriages']&.length
        @form_data['marriageCount'] = @form_data['marriages']&.length

        @form_data['spouseAddress'] = combine_full_address(@form_data['spouseAddress'])

        expand_marital_status(@form_data, 'maritalStatus')

        expand_expected_incomes
        expand_net_worths
        expand_monthly_incomes
        combine_other_expenses

        expand_bank_acct(@form_data['bankAccount'])

        @form_data
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize
    end
  end
end
# rubocop:enable Metrics/ClassLength
