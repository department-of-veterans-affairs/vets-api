# frozen_string_literal: true
module PdfFill
  module Forms
    class VA21P527EZ
      ITERATOR = PdfFill::HashConverter::ITERATOR
      DATE_STRFTIME = '%m/%d/%Y'
      KEY = {
        'vaFileNumber' => 'F[0].Page_5[0].VAfilenumber[0]',
        'spouseSocialSecurityNumber' => 'F[0].Page_6[0].SSN[0]',
        'genderMale' => 'F[0].Page_5[0].Male[0]',
        'genderFemale' => 'F[0].Page_5[0].Female[0]',
        'hasFileNumber' => 'F[0].Page_5[0].YesFiled[0]',
        'noFileNumber' => 'F[0].Page_5[0].NoFiled[0]',
        'hasPowDateRange' => 'F[0].Page_5[0].YesPOW[0]',
        'noPowDateRange' => 'F[0].Page_5[0].NoPOW[0]',
        'monthlySpousePayment' => 'F[0].Page_6[0].MonthlySupport[0]',
        'spouseDateOfBirth' => 'F[0].Page_6[0].Date[8]',
        'noLiveWithSpouse' => 'F[0].Page_6[0].CheckboxSpouseNo[0]',
        'hasLiveWithSpouse' => 'F[0].Page_6[0].CheckboxSpouseYes[0]',
        'noSpouseIsVeteran' => 'F[0].Page_6[0].CheckboxVetNo[0]',
        'hasSpouseIsVeteran' => 'F[0].Page_6[0].CheckboxVetYes[0]',
        'maritalStatusNeverMarried' => 'F[0].Page_6[0].CheckboxMaritalNeverMarried[0]',
        'maritalStatusWidowed' => 'F[0].Page_6[0].CheckboxMaritalWidowed[0]',
        'maritalStatusDivorced' => 'F[0].Page_6[0].CheckboxMaritalDivorced[0]',
        'maritalStatusMarried' => 'F[0].Page_6[0].CheckboxMaritalMarried[0]',
        'expectedIncomes' => {
          'amount' => "expectedIncomes.amount[#{ITERATOR}]",
          'recipient' => "expectedIncomes.recipient[#{ITERATOR}]",
        },
        'hasPreviousNames' => 'F[0].Page_5[0].YesName[0]',
        'noPreviousNames' => 'F[0].Page_5[0].NameNo[0]',
        'hasCombatSince911' => 'F[0].Page_5[0].YesCZ[0]',
        'noCombatSince911' => 'F[0].Page_5[0].NoCZ[0]',
        'spouseMarriagesExplanations' => 'F[0].Page_6[0].Explainothertypeofmarriage[0]',
        'marriagesExplanations' => 'F[0].Page_6[0].Explainothertypesofmarriage[0]',
        'hasSeverancePay' => 'F[0].Page_5[0].YesSep[0]',
        'noSeverancePay' => 'F[0].Page_5[0].NoSep[0]',
        'veteranDateOfBirth' => 'F[0].Page_5[0].Date[0]',
        'spouseVaFileNumber' => 'F[0].Page_6[0].SpouseVAfilenumber[0]',
        'veteranSocialSecurityNumber' => 'F[0].Page_5[0].SSN[0]',
        'severancePay' => {
          'amount' => 'F[0].Page_5[0].Listamount[0]',
          'type' => 'F[0].Page_5[0].Listtype[0]'
        },
        'marriageCount' => 'F[0].Page_6[0].Howmanytimesmarried[0]',
        'spouseMarriageCount' => 'F[0].Page_6[0].Howmanytimesspousemarried[0]',
        'powDateRangeStart' => 'F[0].Page_5[0].Date[1]',
        'powDateRangeEnd' => 'F[0].Page_5[0].Date[2]',
        'jobs' => {
          'annualEarnings' => "F[0].Page_5[0].Totalannualearnings[#{ITERATOR}]",
          'nameAndAddr' => "F[0].Page_5[0].Nameandaddressofemployer[#{ITERATOR}]",
          'jobTitle' => "F[0].Page_5[0].Jobtitle[#{ITERATOR}]",
          'dateRangeStart' => "F[0].Page_5[0].DateJobBegan[#{ITERATOR}]",
          'dateRangeEnd' => "F[0].Page_5[0].DateJobEnded[#{ITERATOR}]",
          'daysMissed' => "F[0].Page_5[0].Dayslostduetodisability[#{ITERATOR}]"
        },
        'spouseMarriages' => {
          'dateOfMarriage' => "spouseMarriages.dateOfMarriage[#{ITERATOR}]",
          'locationOfMarriage' => "spouseMarriages.locationOfMarriage[#{ITERATOR}]",
          'locationOfSeparation' => "spouseMarriages.locationOfSeparation[#{ITERATOR}]",
          'spouseFullName' => "spouseMarriages.spouseFullName[#{ITERATOR}]",
          'marriageType' => "spouseMarriages.marriageType[#{ITERATOR}]",
          'dateOfSeparation' => "spouseMarriages.dateOfSeparation[#{ITERATOR}]",
          'reasonForSeparation' => "spouseMarriages.reasonForSeparation[#{ITERATOR}]"
        },
        'marriages' => {
          'dateOfMarriage' => "marriages.dateOfMarriage[#{ITERATOR}]",
          'locationOfMarriage' => "marriages.locationOfMarriage[#{ITERATOR}]",
          'locationOfSeparation' => "marriages.locationOfSeparation[#{ITERATOR}]",
          'spouseFullName' => "marriages.spouseFullName[#{ITERATOR}]",
          'marriageType' => "marriages.marriageType[#{ITERATOR}]",
          'dateOfSeparation' => "marriages.dateOfSeparation[#{ITERATOR}]",
          'reasonForSeparation' => "marriages.reasonForSeparation[#{ITERATOR}]"
        },
        'nationalGuard' => {
          'nameAndAddr' => 'F[0].Page_5[0].Nameandaddressofunit[0]',
          'phone' => 'F[0].Page_5[0].Unittelephonenumber[0]',
          'date' => 'F[0].Page_5[0].DateofActivation[0]',
          'phoneAreaCode' => 'F[0].Page_5[0].Unittelephoneareacode[0]'
        },
        'spouseAddress' => 'F[0].Page_6[0].Spouseaddress[0]',
        'outsideChildren' => {
          'childAddress' => "outsideChildren.childAddress[#{ITERATOR}]",
          'childFullName' => "outsideChildren.childFullName[#{ITERATOR}]",
          'monthlyPayment' => "outsideChildren.monthlyPayment[#{ITERATOR}]",
          'personWhoLivesWithChild' => "outsideChildren.personWhoLivesWithChild[#{ITERATOR}]"
        },
        'children' => {
          'childSocialSecurityNumber' => "children.childSocialSecurityNumber[#{ITERATOR}]",
          'childDateOfBirth' => "children.childDateOfBirth[#{ITERATOR}]",
          'childPlaceOfBirth' => "children.childPlaceOfBirth[#{ITERATOR}]",
          'attendingCollege' => "children.attendingCollege[#{ITERATOR}]",
          'married' => "children.married[#{ITERATOR}]",
          'disabled' => "children.disabled[#{ITERATOR}]",
          'biological' => "children.biological[#{ITERATOR}]",
          'childFullName' => "children.name[#{ITERATOR}]",
          'adopted' => "children.adopted[#{ITERATOR}]",
          'stepchild' => "children.stepchild[#{ITERATOR}]",
          'previouslyMarried' => "children.previouslyMarried[#{ITERATOR}]"
        },
        "hasNationalGuardActivation" => 'F[0].Page_5[0].YesAD[0]',
        "noNationalGuardActivation" => 'F[0].Page_5[0].NoAD[0]',
        'nightPhone' => 'F[0].Page_5[0].Eveningphonenumber[0]',
        'mobilePhone' => 'F[0].Page_5[0].Cellphonenumber[0]',
        'mobilePhoneAreaCode' => 'F[0].Page_5[0].Cellphoneareacode[0]',
        'nightPhoneAreaCode' => 'F[0].Page_5[0].Eveningareacode[0]',
        'dayPhone' => 'F[0].Page_5[0].Daytimephonenumber[0]',
        'previousNames' => 'F[0].Page_5[0].Listothernames[0]',
        'dayPhoneAreaCode' => 'F[0].Page_5[0].Daytimeareacode[0]',
        'vaHospitalTreatmentNames' => "F[0].Page_5[0].Nameandlocationofvamedicalcenter[#{ITERATOR}]",
        'serviceBranch' => 'F[0].Page_5[0].Branchofservice[0]',
        'veteranAddressLine1' => 'F[0].Page_5[0].Currentaddress[0]',
        'email' => 'F[0].Page_5[0].Preferredemailaddress[0]',
        'altEmail' => 'F[0].Page_5[0].Alternateemailaddress[0]',
        'cityState' => 'F[0].Page_5[0].Citystatezipcodecountry[0]',
        'activeServiceDateRangeStart' => 'F[0].Page_5[0].DateEnteredActiveService[0]',
        'activeServiceDateRangeEnd' => 'F[0].Page_5[0].ReleaseDateorAnticipatedReleaseDate[0]',
        'disabilityNames' => "F[0].Page_5[0].Disability[#{ITERATOR}]",
        'placeOfSeparation' => 'F[0].Page_5[0].Placeofseparation[0]',
        'reasonForNotLivingWithSpouse' => 'F[0].Page_6[0].Reasonfornotlivingwithspouse[0]',
        'disabilities' => {
          'disabilityStartDate' => "F[0].Page_5[0].DateDisabilityBegan[#{ITERATOR}]"
        },
        'vaHospitalTreatmentDates' => "F[0].Page_5[0].DateofTreatment[#{ITERATOR}]",
        'veteranFullName' => 'F[0].Page_5[0].Veteransname[0]'
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

      def convert_date(date)
        return if date.blank?
        Date.parse(date).strftime('%m/%d/%Y')
      end

      def expand_previous_names(previous_names)
        expand_checkbox(previous_names.present?, 'PreviousNames')
      end

      def expand_severance_pay(severance_pay)
        amount = severance_pay.try(:[], 'amount') || 0

        expand_checkbox(amount > 0, 'SeverancePay')
      end

      def expand_chk_and_del_key(hash, key, newKey = nil)
        newKey = key.slice(0,1).capitalize + key.slice(1..-1) if newKey.nil?
        val = hash[key]
        hash.delete(key)

        expand_checkbox(val, newKey)
      end

      def expand_checkbox(value, key)
        {
          "has#{key}" => value,
          "no#{key}" => !value
        }
      end

      def combine_address(address)
        return if address.blank?

        combine_hash(address, %w(street street2), ', ')
      end

      def combine_full_address(address)
        combine_hash(address, %w(
          street
          street2
          city
          state
          postalCode
          country
        ), ', ')
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
        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          combined << combine_hash(va_hospital_treatment, %w(name location), ', ')
        end

        combined
      end

      def combine_name_addr(hash)
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

          alternate_i = i == 0 ? 1 : 0

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
        # order of boxes in the pdf: 3, 2, 4, 0, 1, 5
        rearranged = Array.new(6, nil)

        [3, 2, 4, 0, 1, 5].each_with_index do |rearranged_i, i|
          rearranged[rearranged_i] = combined_dates[i]
        end

        rearranged
      end

      def combine_va_hospital_dates(va_hospital_treatments)
        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          original_dates = va_hospital_treatment['dates']
          dates = Array.new(3, nil)

          dates.each_with_index do |date, i|
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
            hash["maritalStatus#{status.gsub(' ', '_').camelize}"] = true
            break
          end
        end

        hash
      end

      def expand_children(hash, key)
        # TODO spec
        children = hash[key]
        return if children.blank?

        children_split = {
          outside: [],
          cohabiting: []
        }

        children.each do |child|
          children_split[child['childNotInHousehold'] ? :outside : :cohabiting] << child
        end

        3.times do |i|
          children_split.each do |k, v|
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
      end

      def combine_full_name(full_name)
        combine_hash(full_name, %w(first middle last suffix))
      end

      def expand_marriages(hash, key)
        marriages = hash[key]
        return if marriages.blank?
        otherExplanations = []

        marriages.each do |marriage|
          marriage['spouseFullName'] = combine_full_name(marriage['spouseFullName'])
          otherExplanations << marriage['otherExplanation'] if marriage['otherExplanation'].present?
        end

        hash["#{key}Explanations"] = otherExplanations.join(', ')

        hash
      end

      def expand_expected_income(recipient, expected_income, income_types)
        return if expected_income.blank?

        %w(salary interest).each do |income_type|
          income_types[income_type] << {
            'recipient' => recipient,
            'amount' => expected_income[income_type]
          }
        end
      end

      def expand_expected_incomes
        # expectedIncomes.additionalSourceName[3]
        income_types = {
          'salary' => [],
          'interest' => []
        }
        expected_incomes = []
        6.times do
          expected_incomes << {}
        end

        %w(myself spouse).each_with_index do |person, i|
          expected_income = @form_data[
            person == 'myself' ? 'expectedIncome' : 'spouseExpectedIncome'
          ]
          expand_expected_income(person.capitalize, expected_income, income_types)
        end

        @form_data['children']&.each do |child|
          expand_expected_income(child['childFullName'], child['expected_income'], income_types)
        end

        expected_incomes[0] = income_types['salary'][0]
        expected_incomes[1] = income_types['salary'][1]
        expected_incomes[2] = income_types['interest'][0]

        @form_data['expectedIncomes'] = expected_incomes
      end

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
          @form_data.merge!(public_send("expand_chk_and_del_key", @form_data, attr))
        end

        %w(nightPhone dayPhone mobilePhone).each do |attr|
          replace_phone(@form_data, attr)
        end
        replace_phone(@form_data['nationalGuard'], 'phone')

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

        %w(marriages spouseMarriages).each do |marriageType|
          expand_marriages(@form_data, marriageType)
        end

        @form_data['spouseMarriageCount'] = @form_data['spouseMarriages']&.length
        @form_data['marriageCount'] = @form_data['marriages']&.length

        @form_data['spouseAddress'] = combine_full_address(@form_data['spouseAddress'])

        expand_marital_status(@form_data, 'maritalStatus')

        expand_expected_incomes

        @form_data
      end
    end
  end
end
