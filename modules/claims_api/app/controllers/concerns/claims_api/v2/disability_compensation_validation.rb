# frozen_string_literal: false

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation # rubocop:disable Metrics/ModuleLength
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
        # ensure mailing address country is valid
        validate_form_526_current_mailing_address_country!
        # ensure disabilities are valid
        validate_form_526_disabilities!
        # ensure homeless information is valid
        validate_form_526_veteran_homelessness!
        # ensure new address is valid
        validate_form_526_change_of_address!
        # ensure military service pay information is valid
        validate_form_526_service_pay!
        # ensure treament centers information is valid
        validate_form_526_treatments!
        # ensure service information is valid
        validate_form_526_service_information!
        # ensure direct deposit information is valid
        validate_form_526_direct_deposit!
      end

      def validate_form_526_change_of_address!
        return if form_attributes['changeOfAddress'].blank?

        validate_form_526_change_of_address_beginning_date!
        validate_form_526_change_of_address_ending_date!
        validate_form_526_change_of_address_country!
      end

      def validate_form_526_change_of_address_beginning_date!
        change_of_address = form_attributes['changeOfAddress']
        date = change_of_address.dig('dates', 'beginDate')
        return unless 'TEMPORARY'.casecmp?(change_of_address['typeOfAddressChange'])

        # If the date parse fails, then fall back to the InvalidFieldValue
        begin
          return if Date.parse(date) < Time.zone.now
        rescue
          raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.beginDate', date)
        end

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.beginDate', date)
      end

      def validate_form_526_change_of_address_ending_date!
        change_of_address = form_attributes['changeOfAddress']
        date = change_of_address.dig('dates', 'endDate')
        return unless 'TEMPORARY'.casecmp?(change_of_address['typeOfAddressChange'])
        return if Date.parse(date) > Date.parse(change_of_address.dig('dates', 'beginDate'))

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.dates.endDate', date)
      end

      def validate_form_526_change_of_address_country!
        change_of_address = form_attributes['changeOfAddress']
        return if valid_countries.include?(change_of_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('changeOfAddress.country', change_of_address['country'])
      end

      def validate_form_526_submission_claim_date!
        return if form_attributes['claimDate'].blank?
        # EVSS runs in the Central US Time Zone.
        # So 'claim_date' needs to be <= current day according to the Central US Time Zone.
        return if Date.parse(form_attributes['claimDate']) <= Time.find_zone!('Central Time (US & Canada)').today

        raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
      end

      def validate_form_526_claimant_certification!
        return unless form_attributes['claimantCertification'] == false

        raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                          form_attributes['claimantCertification'])
      end

      def validate_form_526_current_mailing_address_country!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if valid_countries.include?(mailing_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('country', mailing_address['country'])
      end

      def valid_countries
        @valid_countries ||= ClaimsApi::BRD.new(request).countries
      end

      def validate_form_526_disabilities!
        validate_form_526_disability_classification_code!
        validate_form_526_diagnostic_code!
        validate_form_526_toxic_exposure!
        validate_form_526_disability_approximate_begin_date!
        validate_form_526_disability_secondary_disabilities!
      end

      def validate_form_526_disability_classification_code!
        return if (form_attributes['disabilities'].pluck('classificationCode') - [nil]).blank?

        form_attributes['disabilities'].each do |disability|
          next if disability['classificationCode'].blank?

          if brd_classification_ids.include?(disability['classificationCode'].to_i)
            validate_form_526_disability_name!(disability['classificationCode'].to_i, disability['name'])
          else
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "'disabilities.classificationCode' must match the associated id " \
                      'value returned from the /disabilities endpoint of the Benefits ' \
                      'Reference Data API.'
            )
          end
        end
      end

      def validate_form_526_disability_name!(classification_code, disability_name)
        if disability_name.blank?
          raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.name',
                                                            disability['name'])
        end
        reference_disability = brd_disabilities.find { |x| x[:id] == classification_code }
        return if reference_disability[:name] == disability_name

        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.name' must match the name value associated " \
                  "with 'disabilities.classificationCode' as returned from the " \
                  '/disabilities endpoint of the Benefits Reference Data API.'
        )
      end

      def brd_classification_ids
        return @brd_classification_ids if @brd_classification_ids.present?

        brd_disabilities_arry = ClaimsApi::BRD.new(request).disabilities
        @brd_classification_ids = brd_disabilities_arry.pluck(:id)
      end

      def brd_disabilities
        return @brd_disabilities if @brd_disabilities.present?

        @brd_disabilities = ClaimsApi::BRD.new(request).disabilities
      end

      def validate_form_526_disability_approximate_begin_date!
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?

        disabilities.each do |disability|
          approx_begin_date = disability['approximateDate']
          next if approx_begin_date.blank?

          next if date_is_valid_against_current_time_after_check_on_format?(approx_begin_date)

          raise ::Common::Exceptions::InvalidFieldValue.new('disability.approximateDate', approx_begin_date)
        end
      end

      def validate_form_526_diagnostic_code!
        form_attributes['disabilities'].each do |disability|
          next unless disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].present?

          if disability['diagnosticCode'].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "'disabilities.diagnosticCode' is required if 'disabilities.disabilityActionType' " \
                      "is 'NONE' and there are secondary disbilities included with the primary."
            )
          end
        end
      end

      def validate_form_526_toxic_exposure!
        form_attributes['disabilities'].each do |disability|
          next unless disability['isRelatedToToxicExposure'] == true

          if disability['exposureOrEventOrInjury'].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: "If disability is related to toxic exposure a value for 'disabilities.exposureOrEventOrInjury' " \
                      'is required.'
            )
          end
        end
      end

      def validate_form_526_disability_secondary_disabilities!
        form_attributes['disabilities'].each do |disability|
          validate_form_526_disability_secondary_disability_disability_action_type!(disability)
          next if disability['secondaryDisabilities'].blank?

          disability['secondaryDisabilities'].each do |secondary_disability|
            if secondary_disability['classificationCode'].present?
              validate_form_526_disability_secondary_disability_classification_code!(secondary_disability)
              validate_form_526_disability_secondary_disability_classification_code_matches_name!(
                secondary_disability
              )
            end

            if secondary_disability['approximateDate'].present?
              validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
            end
          end
        end
      end

      def validate_form_526_disability_secondary_disability_disability_action_type!(disability)
        return unless disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].present?

        if disability['diagnosticCode'].blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "'disabilities.diagnosticCode' is required if 'disabilities.disabilityActionType' " \
                    "is 'NONE' and there are secondary disbilities included with the primary."
          )
        end
      end

      def validate_form_526_disability_secondary_disability_classification_code!(secondary_disability)
        return if brd_classification_ids.include?(secondary_disability['classificationCode'].to_i)

        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.secondaryDisabilities.classificationCode' must match the associated id " \
                  'value returned from the /disabilities endpoint of the Benefits ' \
                  'Reference Data API.'
        )
      end

      def validate_form_526_disability_secondary_disability_classification_code_matches_name!(secondary_disability)
        if secondary_disability['name'].blank?
          raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.secondaryDisabilities.name',
                                                            secondary_disability['name'])
        end
        reference_disability = brd_disabilities.find { |x| x[:id] == secondary_disability['classificationCode'].to_i }
        return if reference_disability[:name] == secondary_disability['name']

        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "'disabilities.secondaryDisabilities.name' must match the name value associated " \
                  "with 'disabilities.secondaryDisabilities.classificationCode' as returned from the " \
                  '/disabilities endpoint of the Benefits Reference Data API.'
        )
      end

      def validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
        return if date_is_valid_against_current_time_after_check_on_format?(secondary_disability['approximateDate'])

        raise ::Common::Exceptions::InvalidFieldValue.new(
          'disabilities.secondaryDisabilities.approximateDate',
          secondary_disability['approximateDate']
        )
      rescue ArgumentError
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'disabilities.secondaryDisabilities.approximateDate',
          secondary_disability['approximateDate']
        )
      end

      def validate_form_526_veteran_homelessness!
        handle_empty_other_description

        if too_many_homelessness_attributes_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "Must define only one of 'homeless.currentlyHomeless' or " \
                    "'homeless.riskOfBecomingHomeless'"
          )
        end

        if unnecessary_homelessness_point_of_contact_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If 'homeless.pointOfContact' is defined, then one of " \
                    "'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is required"
          )
        end

        if missing_point_of_contact?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If one of 'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is " \
                    "defined, then 'homeless.pointOfContact' is required"
          )
        end
      end

      def get_homelessness_attributes
        currently_homeless_attr = form_attributes.dig('homeless', 'currentlyHomeless')
        homelessness_risk_attr = form_attributes.dig('homeless', 'riskOfBecomingHomeless')
        [currently_homeless_attr, homelessness_risk_attr]
      end

      def handle_empty_other_description
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # Set otherDescription to ' ' to bypass docker container validation
        if currently_homeless_attr.present?
          homeless_situation_options = currently_homeless_attr['homelessSituationOptions']
          other_description = currently_homeless_attr['otherDescription']
          if homeless_situation_options == 'OTHER' && other_description.blank?
            form_attributes['homeless']['currentlyHomeless']['otherDescription'] = ' '
          end
        elsif homelessness_risk_attr.present?
          living_situation_options = homelessness_risk_attr['livingSituationOptions']
          other_description = homelessness_risk_attr['otherDescription']
          if living_situation_options == 'other' && other_description.blank?
            form_attributes['homeless']['riskOfBecomingHomeless']['otherDescription'] = ' '
          end
        end
      end

      def too_many_homelessness_attributes_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        # EVSS does not allow both attributes to be provided at the same time
        currently_homeless_attr.present? && homelessness_risk_attr.present?
      end

      def unnecessary_homelessness_point_of_contact_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')

        # EVSS does not allow passing a 'pointOfContact' if neither homelessness attribute is provided
        currently_homeless_attr.blank? && homelessness_risk_attr.blank? && homelessness_poc_attr.present?
      end

      def missing_point_of_contact?
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # 'pointOfContact' is required when either currentlyHomeless or homelessnessRisk is provided
        homelessness_poc_attr.blank? && (currently_homeless_attr.present? || homelessness_risk_attr.present?)
      end

      def validate_form_526_service_pay!
        validate_form_526_military_retired_pay!
        validate_form_526_future_military_retired_pay!
        validate_form_526_separation_pay_received_date!
      end

      def validate_form_526_military_retired_pay!
        receiving_attr = form_attributes.dig('servicePay', 'receivingMilitaryRetiredPay')
        future_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPay')

        return if receiving_attr.nil? || future_attr.nil?
        return unless receiving_attr == future_attr

        # EVSS does not allow both attributes to be the same value (unless that value is nil)
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'servicePay.militaryRetiredPay',
          form_attributes['servicePay']['militaryRetiredPay']
        )
      end

      def validate_form_526_future_military_retired_pay!
        future_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPay')
        future_explanation_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPayExplanation')
        return if future_attr.nil?

        if future_attr == true && future_explanation_attr.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If 'servicePay.futureMilitaryRetiredPay' is true, then " \
                    "'servicePay.futureMilitaryRetiredPayExplanation' is required"
          )
        end
      end

      def validate_form_526_separation_pay_received_date!
        separation_pay_received_date = form_attributes.dig('servicePay', 'separationSeverancePay',
                                                           'datePaymentReceived')
        return if separation_pay_received_date.blank?

        return if date_is_valid_against_current_time_after_check_on_format?(separation_pay_received_date)

        raise ::Common::Exceptions::InvalidFieldValue.new('separationSeverancePay.datePaymentReceived',
                                                          separation_pay_received_date)
      end

      def validate_form_526_treatments!
        treatments = form_attributes['treatments']
        return if treatments.blank?

        validate_treated_disability_names!
      end

      def validate_treated_disability_names!
        treatments = form_attributes['treatments']

        treated_disability_names = collect_treated_disability_names(treatments)
        declared_disability_names = collect_primary_secondary_disability_names(form_attributes['disabilities'])

        treated_disability_names.each do |treatment|
          next if declared_disability_names.include?(treatment)

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'The treated disability must match a disability listed above'
          )
        end
      end

      def collect_treated_disability_names(treatments)
        names = []
        treatments.each do |treatment|
          if treatment['treatedDisabilityNames'].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Treated disability names are required.'
            )
          end

          treatment['treatedDisabilityNames'].each do |disability_name|
            names << disability_name.strip.downcase
          end
        end
        names
      end

      def collect_primary_secondary_disability_names(disabilities)
        names = []
        disabilities.each do |disability|
          names << disability['name'].strip.downcase
          disability['secondaryDisabilities'].each do |secondary|
            names << secondary['name'].strip.downcase
          end
        end
        names
      end

      def validate_form_526_service_information!
        service_information = form_attributes['serviceInformation']

        if service_information.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'Service information is required'
          )
        end
        if activation_date_not_afterduty_begin_date?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'The title 10 activation date must be after the earliest service period active duty begin date.'
          )
        end

        validate_service_periods!
        validate_confinements!
        validate_anticipated_seperation_date!
        validate_alternate_names!
        validate_reserves_tos_dates!
      end

      def validate_service_periods!
        service_information = form_attributes['serviceInformation']

        service_information['servicePeriods'].each do |sp|
          if Date.parse(sp['activeDutyBeginDate']) > Date.parse(sp['activeDutyEndDate'])
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Active Duty End Date needs to be after Active Duty Start Date'
            )
          end

          if Date.parse(sp['activeDutyEndDate']) > Time.zone.now && sp['separationLocationCode'].empty?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'If Active Duty End Date is in the future a Separation Location Code is required.'
            )
          end
        end
      end

      def validate_confinements!
        service_information = form_attributes['serviceInformation']

        service_information['confinements'].each do |confinement|
          approximate_begin_date = confinement['approximateBeginDate']
          approximate_end_date = confinement['approximateEndDate']

          if begin_date_is_not_after_end_date?(approximate_begin_date, approximate_end_date)
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Approximate end date must be after approximate begin date.'
            )
          end
        end
      end

      def validate_anticipated_seperation_date!
        service_information = form_attributes['serviceInformation']

        anticipated_seperation_date =
          service_information['reservesNationalGuardService']['title10Activation']['anticipatedSeparationDate']

        if Date.parse(anticipated_seperation_date) < Time.zone.now
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'The anticipated separation date must be a date in the future.'
          )
        end
      end

      def validate_alternate_names!
        alternate_names = form_attributes['serviceInformation']['alternateNames']
        return if alternate_names.blank?

        # clean them up to compare
        alternate_names = alternate_names.map(&:strip).map(&:downcase)

        # returns nil unless there are duplicate names
        duplicate_names_check = alternate_names.detect { |e| alternate_names.rindex(e) != alternate_names.index(e) }

        unless duplicate_names_check.nil?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'Names entered as an alternate name must be unique.'
          )
        end
      end

      def activation_date_not_afterduty_begin_date?
        service_information = form_attributes['serviceInformation']
        service_periods = service_information['servicePeriods']
        activation_date =
          service_information['reservesNationalGuardService']['title10Activation']['title10ActivationDate']

        earliest_active_duty_begin_date = service_periods.max_by { |a| Date.parse(a['activeDutyBeginDate']) }

        # return true if activationDate is an earlier date
        Date.parse(activation_date) < Date.parse(earliest_active_duty_begin_date['activeDutyBeginDate'])
      end

      def validate_reserves_tos_dates!
        service_information = form_attributes['serviceInformation']

        tos_start_date = service_information['reservesNationalGuardService']['obligationTermsOfService']['beginDate']
        tos_end_date = service_information['reservesNationalGuardService']['obligationTermsOfService']['endDate']
        if Date.parse(tos_start_date) > Date.parse(tos_end_date)
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'Terms of service Start date must be before the terms of service end date.'
          )
        end
      end

      def validate_form_526_direct_deposit!
        direct_deposit = form_attributes['directDeposit']
        return if direct_deposit.blank?

        account_check = direct_deposit&.dig('noAccount')

        account_check.present? && account_check == true ? validate_no_account! : validate_account_values!
      end

      def validate_no_account!
        acc_vals = form_attributes['directDeposit']

        raise_exception_on_invalid_account_values('account type') if acc_vals['accountType'].present?
        raise_exception_on_invalid_account_values('account number') if acc_vals['accountNumber'].present?
        raise_exception_on_invalid_account_values('routing number') if acc_vals['routingNumber'].present?
        if acc_vals['financialInstitutionName'].present?
          raise_exception_on_invalid_account_values('financial institution name')
        end
      end

      def raise_exception_on_invalid_account_values(account_detail)
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "If the claimant has no account the #{account_detail} field must be left empty."
        )
      end

      def validate_account_values!
        direct_deposit_account_vals = form_attributes['directDeposit']

        valid_account_types = %w[CHECKING SAVINGS]
        account_type = direct_deposit_account_vals&.dig('accountType')
        account_number = direct_deposit_account_vals&.dig('accountNumber')
        routing_number = direct_deposit_account_vals&.dig('routingNumber')

        if account_type.blank? || valid_account_types.exclude?(account_type)
          raise_exception_if_value_present('account type (CHECKING/SAVINGS)')
        end
        raise_exception_if_value_present('account number') if account_number.blank?
        raise_exception_if_value_present('routing number') if routing_number.blank?
      end

      def raise_exception_if_value_present(val)
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "The #{val} is required for direct deposit."
        )
      end

      private

      def begin_date_is_not_after_end_date?(begin_date, end_date)
        # see what format each date is in
        begin_date_has_day = date_has_day?(begin_date)
        end_date_has_day = date_has_day?(end_date)
        # determine how to compare, being = is ok
        if (begin_date_has_day && end_date_has_day) || (!begin_date_has_day && !end_date_has_day) # same format
          begin_date > end_date
        else # mixed formats on dates
          begin_date_not_after_end_date_with_mixed_format_dates?(begin_date, end_date)
        end
      end

      # Either date could be in MM-YYYY or MM-DD-YYYY format
      def begin_date_not_after_end_date_with_mixed_format_dates?(begin_date, end_date)
        # figure out which one has the day and remove it
        if date_has_day?(begin_date)
          begin_date = remove_chars(begin_date.dup)
        elsif date_has_day?(end_date)
          end_date = remove_chars(end_date.dup)
        end
        Date.strptime(begin_date, '%m-%Y') > Date.strptime(end_date, '%m-%Y') # = is ok
      end

      def date_is_valid_against_current_time_after_check_on_format?(date)
        if date_has_day?(date)
          param_date = Date.strptime(date, '%m-%d-%Y')
          now_date = Date.strptime(Time.zone.today.strftime('%m-%d-%Y'), '%m-%d-%Y')
        else
          param_date = Date.strptime(date, '%m-%Y')
          now_date = Date.strptime(Time.zone.today.strftime('%m-%Y'), '%m-%Y')
        end
        param_date <= now_date # Since it is approximate we go with <=
      end

      # just need to know if day is present or not
      def date_has_day?(date)
        date.length == 10
      end

      # making date approximate to compare
      def remove_chars(str)
        indices = [2, 3, 4] # MM| -DD |-YYYY
        indices.reverse_each { |i| str[i] = '' }
        str
      end
    end
  end
end
