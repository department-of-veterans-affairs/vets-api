# frozen_string_literal: true
# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class VA21P527EZ
      # TODO convert or remove xx dates

      ITERATOR = PdfFill::HashConverter::ITERATOR
      DATE_STRFTIME = '%m/%d/%Y'
      KEY = {
        'vaFileNumber' => { key: 'F[0].Page_5[0].VAfilenumber[0]' },
        'spouseSocialSecurityNumber' => { key: 'F[0].Page_6[0].SSN[0]' },
        'genderMale' => { key: 'F[0].Page_5[0].Male[0]' },
        'genderFemale' => { key: 'F[0].Page_5[0].Female[0]' },
        'hasFileNumber' => { key: 'F[0].Page_5[0].YesFiled[0]' },
        'noFileNumber' => { key: 'F[0].Page_5[0].NoFiled[0]' },
        'hasPowDateRange' => { key: 'F[0].Page_5[0].YesPOW[0]' },
        'noPowDateRange' => { key: 'F[0].Page_5[0].NoPOW[0]' },
        'monthlySpousePayment' => { key: 'F[0].Page_6[0].MonthlySupport[0]' },
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
        'checkingAccountNumber' => { key: 'F[0].Page_8[0].CheckingAccountNumber[0]' },
        'noRapidProcessing' => { key: 'F[0].Page_8[0].CheckBox1[0]' },
        'savingsAccountNumber' => { key: 'F[0].Page_8[0].SavingsAccountNumber[0]' },
        'bankAccount' => {
          'bankName' => { key: 'F[0].Page_8[0].Nameofbank[0]' },
          'routingNumber' => { key: 'F[0].Page_8[0].Routingortransitnumber[0]' }
        },
        'noBankAccount' => { key: 'F[0].Page_8[0].Account[1]' },
        'monthlyIncomes' => {
          'amount' => { key: 'monthlyIncomes.amount[%iterator%]' },
          'additionalSourceName' => { key: 'monthlyIncomes.additionalSourceName[%iterator%]' },
          'recipient' => { key: 'monthlyIncomes.recipient[%iterator%]' }
        },
        'otherExpenses' => {
          'amount' => { key: 'otherExpenses.amount[%iterator%]' },
          'purpose' => { key: 'otherExpenses.purpose[%iterator%]' },
          'paidTo' => { key: 'otherExpenses.paidTo[%iterator%]' },
          'relationship' => { key: 'otherExpenses.relationship[%iterator%]' },
          'date' => { key: 'otherExpenses.date[%iterator%]' }
        },
        'netWorths' => {
          'amount' => { key: 'netWorths.amount[%iterator%]' },
          'additionalSourceName' => { key: 'netWorths.additionalSourceName[%iterator%]' },
          'recipient' => { key: 'netWorths.recipient[%iterator%]' }
        },
        'expectedIncomes' => {
          'amount' => { key: 'expectedIncomes.amount[%iterator%]' },
          'additionalSourceName' => { key: 'expectedIncomes.additionalSourceName[%iterator%]' },
          'recipient' => { key: 'expectedIncomes.recipient[%iterator%]' }
        },
        'hasPreviousNames' => { key: 'F[0].Page_5[0].YesName[0]' },
        'noPreviousNames' => { key: 'F[0].Page_5[0].NameNo[0]' },
        'hasCombatSince911' => { key: 'F[0].Page_5[0].YesCZ[0]' },
        'noCombatSince911' => { key: 'F[0].Page_5[0].NoCZ[0]' },
        'spouseMarriagesExplanations' => { key: 'F[0].Page_6[0].Explainothertypeofmarriage[0]' },
        'marriagesExplanations' => { key: 'F[0].Page_6[0].Explainothertypesofmarriage[0]' },
        'hasSeverancePay' => { key: 'F[0].Page_5[0].YesSep[0]' },
        'noSeverancePay' => { key: 'F[0].Page_5[0].NoSep[0]' },
        'veteranDateOfBirth' => { key: 'F[0].Page_5[0].Date[0]' },
        'spouseVaFileNumber' => { key: 'F[0].Page_6[0].SpouseVAfilenumber[0]' },
        'veteranSocialSecurityNumber' => { key: 'F[0].Page_5[0].SSN[0]' },
        'severancePay' => {
          'amount' => { key: 'F[0].Page_5[0].Listamount[0]' },
          'type' => { key: 'F[0].Page_5[0].Listtype[0]' }
        },
        'marriageCount' => { key: 'F[0].Page_6[0].Howmanytimesmarried[0]' },
        'spouseMarriageCount' => { key: 'F[0].Page_6[0].Howmanytimesspousemarried[0]' },
        'powDateRangeStart' => { key: 'F[0].Page_5[0].Date[1]' },
        'powDateRangeEnd' => { key: 'F[0].Page_5[0].Date[2]' },
        'jobs' => {
          'annualEarnings' => { key: 'F[0].Page_5[0].Totalannualearnings[%iterator%]' },
          'nameAndAddr' => { key: 'F[0].Page_5[0].Nameandaddressofemployer[%iterator%]' },
          'jobTitle' => { key: 'F[0].Page_5[0].Jobtitle[%iterator%]' },
          'dateRangeStart' => { key: 'F[0].Page_5[0].DateJobBegan[%iterator%]' },
          'dateRangeEnd' => { key: 'F[0].Page_5[0].DateJobEnded[%iterator%]' },
          'daysMissed' => { key: 'F[0].Page_5[0].Dayslostduetodisability[%iterator%]' }
        },
        'spouseMarriages' => {
          'dateOfMarriage' => { key: 'spouseMarriages.dateOfMarriage[%iterator%]' },
          'locationOfMarriage' => { key: 'spouseMarriages.locationOfMarriage[%iterator%]' },
          'locationOfSeparation' => { key: 'spouseMarriages.locationOfSeparation[%iterator%]' },
          'spouseFullName' => { key: 'spouseMarriages.spouseFullName[%iterator%]' },
          'marriageType' => { key: 'spouseMarriages.marriageType[%iterator%]' },
          'dateOfSeparation' => { key: 'spouseMarriages.dateOfSeparation[%iterator%]' },
          'reasonForSeparation' => { key: 'spouseMarriages.reasonForSeparation[%iterator%]' }
        },
        'marriages' => {
          'dateOfMarriage' => { key: 'marriages.dateOfMarriage[%iterator%]' },
          'locationOfMarriage' => { key: 'marriages.locationOfMarriage[%iterator%]' },
          'locationOfSeparation' => { key: 'marriages.locationOfSeparation[%iterator%]' },
          'spouseFullName' => { key: 'marriages.spouseFullName[%iterator%]' },
          'marriageType' => { key: 'marriages.marriageType[%iterator%]' },
          'dateOfSeparation' => { key: 'marriages.dateOfSeparation[%iterator%]' },
          'reasonForSeparation' => { key: 'marriages.reasonForSeparation[%iterator%]' }
        },
        'nationalGuard' => {
          'nameAndAddr' => { key: 'F[0].Page_5[0].Nameandaddressofunit[0]' },
          'phone' => { key: 'F[0].Page_5[0].Unittelephonenumber[0]' },
          'date' => { key: 'F[0].Page_5[0].DateofActivation[0]' },
          'phoneAreaCode' => { key: 'F[0].Page_5[0].Unittelephoneareacode[0]' }
        },
        'spouseAddress' => { key: 'F[0].Page_6[0].Spouseaddress[0]' },
        'outsideChildren' => {
          'childAddress' => { key: 'outsideChildren.childAddress[%iterator%]' },
          'childFullName' => { key: 'outsideChildren.childFullName[%iterator%]' },
          'monthlyPayment' => { key: 'outsideChildren.monthlyPayment[%iterator%]' },
          'personWhoLivesWithChild' => { key: 'outsideChildren.personWhoLivesWithChild[%iterator%]' }
        },
        'children' => {
          'childSocialSecurityNumber' => { key: 'children.childSocialSecurityNumber[%iterator%]' },
          'childDateOfBirth' => { key: 'children.childDateOfBirth[%iterator%]' },
          'childPlaceOfBirth' => { key: 'children.childPlaceOfBirth[%iterator%]' },
          'attendingCollege' => { key: 'children.attendingCollege[%iterator%]' },
          'married' => { key: 'children.married[%iterator%]' },
          'disabled' => { key: 'children.disabled[%iterator%]' },
          'biological' => { key: 'children.biological[%iterator%]' },
          'childFullName' => { key: 'children.name[%iterator%]' },
          'adopted' => { key: 'children.adopted[%iterator%]' },
          'stepchild' => { key: 'children.stepchild[%iterator%]' },
          'previouslyMarried' => { key: 'children.previouslyMarried[%iterator%]' }
        },
        'hasNationalGuardActivation' => { key: 'F[0].Page_5[0].YesAD[0]' },
        'noNationalGuardActivation' => { key: 'F[0].Page_5[0].NoAD[0]' },
        'nightPhone' => { key: 'F[0].Page_5[0].Eveningphonenumber[0]' },
        'mobilePhone' => { key: 'F[0].Page_5[0].Cellphonenumber[0]' },
        'mobilePhoneAreaCode' => { key: 'F[0].Page_5[0].Cellphoneareacode[0]' },
        'nightPhoneAreaCode' => { key: 'F[0].Page_5[0].Eveningareacode[0]' },
        'dayPhone' => { key: 'F[0].Page_5[0].Daytimephonenumber[0]' },
        'previousNames' => { key: 'F[0].Page_5[0].Listothernames[0]' },
        'dayPhoneAreaCode' => { key: 'F[0].Page_5[0].Daytimeareacode[0]' },
        'vaHospitalTreatmentNames' => { key: 'F[0].Page_5[0].Nameandlocationofvamedicalcenter[%iterator%]' },
        'serviceBranch' => { key: 'F[0].Page_5[0].Branchofservice[0]' },
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
        'disabilityNames' => { key: 'F[0].Page_5[0].Disability[%iterator%]' },
        'placeOfSeparation' => { key: 'F[0].Page_5[0].Placeofseparation[0]' },
        'reasonForNotLivingWithSpouse' => { key: 'F[0].Page_6[0].Reasonfornotlivingwithspouse[0]' },
        'disabilities' => {
          'disabilityStartDate' => { key: 'F[0].Page_5[0].DateDisabilityBegan[%iterator%]' }
        },
        'vaHospitalTreatmentDates' => { key: 'F[0].Page_5[0].DateofTreatment[%iterator%]' },
        'veteranFullName' => {
          limit: 30,
          question: "1. VETERAN'S NAME",
          key: 'F[0].Page_5[0].Veteransname[0]'
        }
      }.freeze

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

      def combine_va_hospital_names(va_hospital_treatments)
        return if va_hospital_treatments.blank?

        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          combined << combine_hash(va_hospital_treatment, %w(name location), ', ')
        end

        combined
      end

      def combine_name_addr(hash)
        return if hash.blank?

        hash['address'] = combine_full_address(hash['address'])
        combine_hash_and_del_keys(hash, %w(name address), 'nameAndAddr', ', ')
      end

      def get_disability_names(disabilities)
        return if disabilities.blank?

        disability_names = Array.new(2, nil)

        disability_names[0] = disabilities[1].try(:[], 'name')
        disability_names[1] = disabilities[0]['name']

        disabilities.map! do |disability|
          disability.except('name')
        end

        disability_names
      end

      def rearrange_jobs(jobs)
        return if jobs.blank?
        new_jobs = [{}, {}]

        2.times do |i|
          %w(daysMissed dateRange).each do |attr|
            new_jobs[i][attr] = jobs[i].try(:[], attr)
          end

          alternate_i = i.zero? ? 1 : 0

          %w(jobTitle annualEarnings).each do |attr|
            new_jobs[i][attr] = jobs[alternate_i].try(:[], attr)
          end

          new_jobs[i]['address'] = combine_full_address(jobs[alternate_i].try(:[], 'address'))
          new_jobs[i]['employer'] = jobs[alternate_i].try(:[], 'employer')
          combine_hash_and_del_keys(new_jobs[i], %w(employer address), 'nameAndAddr', ', ')
        end

        new_jobs
      end

      def rearrange_hospital_dates(combined_dates)
        return if combined_dates.blank?
        # order of boxes in the pdf: 3, 2, 4, 0, 1, 5
        rearranged = Array.new(6, nil)

        [3, 2, 4, 0, 1, 5].each_with_index do |rearranged_i, i|
          rearranged[rearranged_i] = combined_dates[i]
        end

        rearranged
      end

      def combine_va_hospital_dates(va_hospital_treatments)
        return if va_hospital_treatments.blank?
        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          original_dates = va_hospital_treatment['dates']
          dates = Array.new(3, nil)

          3.times do |i|
            dates[i] = original_dates[i]
          end if original_dates.present?

          combined += dates
        end

        combined
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
          children_split[child['childNotInHousehold'] ? :outside : :cohabiting] << child
        end

        children_split
      end

      def expand_children(hash, key)
        children = hash[key]
        return if children.blank?

        children_split = split_children(children)

        3.times do |i|
          children_split.each do |_k, v|
            v[i] ||= {}
            child = v[i]

            %w(childFullName personWhoLivesWithChild).each do |attr|
              child[attr] = combine_full_name(child[attr])
            end

            child['childAddress'] = combine_full_address(child['childAddress'])
          end
        end

        hash[key] = children_split[:cohabiting]
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

        all_children = @form_data['children'] || []
        all_children += @form_data['outsideChildren'] || []

        all_children.each do |child|
          expand_financial_acct(child['childFullName'], child[definition], financial_accts)
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

        @form_data['monthlyIncomes'] = monthly_incomes
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
          otherProperty
        ).each_with_index do |acct_type, i|
          net_worths[i] = financial_accts[acct_type][0]
        end
        net_worths[6] = financial_accts['otherProperty'][1]
        net_worths[7] = financial_accts['additionalSources'][0]

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

      def replace_phone_fields
        %w(nightPhone dayPhone mobilePhone).each do |attr|
          replace_phone(@form_data, attr)
        end
        replace_phone(@form_data['nationalGuard'], 'phone')
      end

      # rubocop:disable Metrics/AbcSize
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

        @form_data['vaHospitalTreatments'].tap do |va_hospital_treatments|
          @form_data['vaHospitalTreatmentNames'] = combine_va_hospital_names(va_hospital_treatments)
          @form_data['vaHospitalTreatmentDates'] = rearrange_hospital_dates(
            combine_va_hospital_dates(va_hospital_treatments)
          )
        end
        @form_data.delete('vaHospitalTreatments')

        @form_data['disabilityNames'] = get_disability_names(@form_data['disabilities'])

        @form_data['cityState'] = combine_city_state(@form_data['veteranAddress'])
        @form_data['veteranAddressLine1'] = combine_address(@form_data['veteranAddress'])
        @form_data.delete('veteranAddress')

        @form_data['previousNames'] = combine_previous_names(@form_data['previousNames'])

        combine_name_addr(@form_data['nationalGuard'])

        @form_data['jobs'] = rearrange_jobs(@form_data['jobs'])

        %w(activeServiceDateRange powDateRange).each do |attr|
          expand_date_range(@form_data, attr)
        end

        @form_data['jobs'].tap do |jobs|
          next if jobs.blank?

          jobs.each do |job|
            expand_date_range(job, 'dateRange')
          end
        end

        expand_children(@form_data, 'children')

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

        expand_bank_acct(@form_data['bankAccount'])

        @form_data
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize
    end
  end
end
# rubocop:enable Metrics/ClassLength
