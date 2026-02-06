# frozen_string_literal: false

require 'claims_api/v2/disability_compensation_shared_service_module'
require 'claims_api/lighthouse_military_address_validator'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation # rubocop:disable Metrics/ModuleLength
      include DisabilityCompensationSharedServiceModule
      include LighthouseMilitaryAddressValidator

      DATE_FORMATS = {
        10 => 'yyyy-mm-dd',
        7 => 'yyyy-mm',
        4 => 'yyyy'
      }.freeze

      BDD_LOWER_LIMIT = 90
      BDD_UPPER_LIMIT = 180

      CLAIM_DATE = Time.find_zone!('Central Time (US & Canada)').today.freeze
      YYYY_YYYYMM_REGEX = '^(?:19|20)[0-9][0-9]$|^(?:19|20)[0-9][0-9]-(0[1-9]|1[0-2])$'.freeze
      YYYY_MM_DD_REGEX = '^(?:[0-9]{4})-(?:0[1-9]|1[0-2])-(?:0[1-9]|[1-2][0-9]|3[0-1])$'.freeze
      ALT_NAMES_REGEX = "^([-a-zA-Z0-9/']+( ?))+$".freeze

      def validate_form_526_submission_values(target_veteran)
        return if form_attributes.empty?

        validate_claim_process_type_bdd if bdd_claim?
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification
        # ensure mailing address country is valid
        validate_form_526_identification
        # ensure disabilities are valid
        validate_form_526_disabilities
        # ensure homeless information is valid
        validate_form_526_veteran_homelessness
        # ensure toxic exposure info is valid
        validate_form_526_toxic_exposure
        # ensure new address is valid
        validate_form_526_change_of_address
        # ensure military service pay information is valid
        validate_form_526_service_pay
        # ensure treatment centers information is valid
        validate_form_526_treatments
        # ensure service information is valid
        validate_form_526_service_information(target_veteran)
        # ensure direct deposit information is valid
        validate_form_526_direct_deposit
        # collect errors and pass back to the controller
        error_collection if @errors
      end

      private

      def validate_form_526_change_of_address
        return if form_attributes['changeOfAddress'].blank?

        validate_form_526_change_of_address_required_fields
        validate_form_526_change_of_address_beginning_date
        validate_form_526_change_of_address_ending_date
        validate_form_526_change_of_address_country
        validate_form_526_change_of_address_state
        validate_form_526_change_of_address_zip
      end

      def validate_form_526_change_of_address_required_fields
        change_of_address = form_attributes['changeOfAddress']

        form_object_desc = '/changeOfAddress'

        validate_form_526_coa_type_of_address_change_presence(change_of_address, form_object_desc)
        validate_form_526_coa_address_line_one_presence(change_of_address, form_object_desc)
        validate_form_526_coa_country_presence(change_of_address, form_object_desc)
        validate_form_526_coa_city_presence(change_of_address, form_object_desc)
      end

      def validate_form_526_coa_type_of_address_change_presence(change_of_address, form_object_desc)
        type_of_address_change = change_of_address&.dig('typeOfAddressChange')
        collect_error_if_value_not_present('typeOfAddressChange', form_object_desc) if type_of_address_change.blank?
      end

      def validate_form_526_coa_address_line_one_presence(change_of_address, form_object_desc)
        address_line_one = change_of_address&.dig('addressLine1')
        collect_error_if_value_not_present('addressLine1', form_object_desc) if address_line_one.blank?
      end

      def validate_form_526_coa_country_presence(change_of_address, form_object_desc)
        country = change_of_address&.dig('country')
        collect_error_if_value_not_present('country', form_object_desc) if country.blank?
      end

      def validate_form_526_coa_city_presence(change_of_address, form_object_desc)
        city = change_of_address&.dig('city')
        collect_error_if_value_not_present('city', form_object_desc) if city.blank?
      end

      def validate_form_526_change_of_address_beginning_date
        change_of_address = form_attributes['changeOfAddress']
        date = change_of_address.dig('dates', 'beginDate')
        return if date.nil? # nullable on schema

        # If the date parse fails, then fall back to the InvalidFieldValue
        begin
          nil if Date.strptime(date, '%Y-%m-%d') < Time.zone.now
        rescue
          collect_error_messages(source: '/changeOfAddress/dates/beginDate', detail: 'beginDate is not a valid date.')
        end
      end

      def validate_form_526_change_of_address_ending_date
        change_of_address = form_attributes&.dig('changeOfAddress')
        date = change_of_address&.dig('dates', 'endDate')
        return if date.nil? # nullable on schema

        if 'PERMANENT'.casecmp?(change_of_address['typeOfAddressChange']) && date.present?
          collect_error_messages(
            detail: 'Change of address endDate cannot be included when typeOfAddressChange is PERMANENT',
            source: '/changeOfAddress/dates/endDate'
          )
        end

        return if change_of_address['dates']['beginDate'].blank? # nothing to check against

        # cannot compare invalid dates so need to return here if date is invalid
        return unless date_is_valid?(date, 'changeOfAddress/dates/endDate')

        if Date.strptime(date, '%Y-%m-%d') < Date.strptime(change_of_address.dig('dates', 'beginDate'), '%Y-%m-%d')
          collect_error_messages(
            source: '/changeOfAddress/dates/endDate',
            detail: 'endDate needs to be after beginDate.'
          )
        end
      end

      def validate_form_526_change_of_address_country
        country = form_attributes.dig('changeOfAddress', 'country')
        return if country.nil? || valid_countries.include?(country)

        collect_error_messages(
          source: '/changeOfAddress/country',
          detail: 'The country provided is not valid.'
        )
      end

      def validate_form_526_change_of_address_state
        address = form_attributes['changeOfAddress'] || {}
        return if address['country'] != 'USA' || address['state'].present?

        collect_error_messages(
          source: '/changeOfAddress/state',
          detail: 'The state is required if the country is USA.'
        )
      end

      def validate_form_526_change_of_address_zip
        address = form_attributes['changeOfAddress'] || {}
        validate_form_526_usa_coa_conditions(address) if address['country'] == 'USA'
      end

      def validate_form_526_usa_coa_conditions(address)
        if address['zipFirstFive'].blank?
          collect_error_messages(
            source: '/changeOfAddress/',
            detail: 'The zipFirstFive is required if the country is USA.'
          )
        end
        if address['state'].blank?
          collect_error_messages(
            source: '/changeOfAddress/',
            detail: 'The state is required if the country is USA.'
          )
        end
        if address['internationalPostalCode'].present?
          collect_error_messages(
            source: '/changeOfAddress/internationalPostalCode',
            detail: 'The internationalPostalCode should not be provided if the country is USA.'
          )
        end
      end

      def validate_form_526_claimant_certification
        return unless form_attributes['claimantCertification'] == false

        collect_error_messages(
          source: '/claimantCertification',
          detail: 'claimantCertification must not be false.'
        )
      end

      def validate_form_526_identification
        return if form_attributes['veteranIdentification'].blank?

        validate_form_526_address_type
        validate_form_526_current_mailing_address_country
        validate_form_526_current_mailing_address_state
        validate_form_526_current_mailing_address_zip
        validate_form_526_service_number
      end

      def validate_form_526_address_type
        addr = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return unless address_is_military?(addr)

        city = military_city(addr)
        state = military_state(addr)
        # need both to be true to be valid
        return if MILITARY_CITY_CODES.include?(city) && MILITARY_STATE_CODES.include?(state)

        collect_error_messages(
          source: '/veteranIdentification/mailingAddress/',
          detail: 'Invalid city and military postal combination.'
        )
      end

      def validate_form_526_service_number
        service_num = form_attributes.dig('veteranIdentification', 'serviceNumber')
        return if service_num.nil?

        if service_num.length > 9
          collect_error_messages(source: '/veteranIdentification/serviceNumber', detail: 'serviceNumber is too long.')
        end
      end

      def validate_form_526_current_mailing_address_country
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if valid_countries.include?(mailing_address['country'])

        collect_error_messages(
          source: '/veteranIdentification/mailingAddress/country',
          detail: 'The country provided is not valid.'
        )
      end

      def validate_form_526_current_mailing_address_state
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if mailing_address['country'] != 'USA' || mailing_address['state'].present?

        collect_error_messages(
          source: '/veteranIdentification/mailingAddress/state',
          detail: 'The state is required if the country is USA.'
        )
      end

      def validate_form_526_current_mailing_address_zip
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        if mailing_address['country'] == 'USA' && mailing_address['zipFirstFive'].blank?
          collect_error_messages(
            source: '/veteranIdentification/mailingAddress/zipFirstFive',
            detail: 'The zipFirstFive is required if the country is USA.'
          )
        elsif mailing_address['country'] == 'USA' && mailing_address['internationalPostalCode'].present?
          collect_error_messages(
            source: '/veteranIdentification/mailingAddress/internationalPostalCode',
            detail: 'The internationalPostalCode should not be provided if the country is USA.'
          )
        end
      end

      def validate_form_526_disabilities
        return if form_attributes['disabilities'].nil? || form_attributes['disabilities'].blank?

        validate_disability_name
        validate_form_526_disability_classification_code
        validate_form_526_disability_approximate_begin_date
        validate_form_526_disability_service_relevance
        validate_form_526_disability_secondary_disabilities
        validate_special_issues
      end

      def validate_disability_name
        form_attributes['disabilities'].each_with_index do |disability, idx|
          disability_name = disability&.dig('name')
          if disability_name.blank?
            collect_error_messages(source: "/disabilities/#{idx}/name",
                                   detail: "The disability name (#{idx}) is required.")
          end
        end
      end

      def validate_form_526_disability_classification_code
        return if (form_attributes['disabilities'].pluck('classificationCode') - [nil]).blank?

        form_attributes['disabilities'].each_with_index do |disability, idx|
          next if disability['classificationCode'].blank?

          if brd_classification_ids.include?(disability['classificationCode'].to_i)

            validate_form_526_disability_code_enddate(disability['classificationCode'].to_i, idx)
          else
            collect_error_messages(source: "/disabilities/#{idx}/classificationCode",
                                   detail: "The classificationCode (#{idx}) must match an active code " \
                                           'returned from the /disabilities endpoint of the Benefits ')
          end
        end
      end

      def validate_form_526_disability_code_enddate(classification_code, idx, sd_idx = nil)
        reference_disability = brd_disabilities.find { |x| x[:id] == classification_code }
        end_date_time = reference_disability[:endDateTime] if reference_disability
        return if end_date_time.nil?

        if Date.parse(end_date_time) < Time.zone.today
          source_message = if sd_idx
                             "disabilities/#{idx}/secondaryDisability/#{sd_idx}/classificationCode"
                           else
                             "disabilities/#{idx}/classificationCode"
                           end
          collect_error_messages(source: source_message,
                                 detail: 'The classificationCode is no longer active.')
        end
      end

      def validate_form_526_disability_approximate_begin_date
        disabilities = form_attributes&.dig('disabilities')
        return if disabilities.blank?

        disabilities.each_with_index do |disability, idx|
          approx_begin_date = disability&.dig('approximateDate')
          next if approx_begin_date.blank?

          next unless date_is_valid?(approx_begin_date, "disability/#{idx}/approximateDate")

          next if date_is_valid_against_current_time_after_check_on_format?(approx_begin_date)

          collect_error_messages(source: "disabilities/#{idx}/approximateDate",
                                 detail: "The approximateDate (#{idx}) is not valid.")
        end
      end

      def validate_form_526_disability_service_relevance
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?

        disabilities.each_with_index do |disability, idx|
          disability_action_type = disability&.dig('disabilityActionType')
          service_relevance = disability&.dig('serviceRelevance')
          if disability_action_type == 'NEW' && service_relevance.blank?
            collect_error_messages(source: "disabilities/#{idx}/serviceRelevance",
                                   detail: "The serviceRelevance (#{idx}) is required if " \
                                           "'disabilityActionType' is NEW.")
          end
        end
      end

      def validate_special_issues
        form_attributes['disabilities'].each_with_index do |disability, idx|
          next if disability['specialIssues'].blank?

          confinements = form_attributes['serviceInformation']&.dig('confinements')
          disability_action_type = disability&.dig('disabilityActionType')
          if disability['specialIssues'].include? 'POW'
            if confinements.blank?
              collect_error_messages(source: "disabilities/#{idx}/specialIssues",
                                     detail: "serviceInformation.confinements (#{idx}) is required if " \
                                             'specialIssues includes POW.')
            elsif disability_action_type == 'INCREASE'
              collect_error_messages(source: "disabilities/#{idx}/specialIssues",
                                     detail: "disabilityActionType (#{idx}) cannot be INCREASE if " \
                                             'specialIssues includes POW for.')
            end
          end
        end
      end

      def validate_form_526_disability_secondary_disabilities # rubocop:disable Metrics/MethodLength
        form_attributes['disabilities'].each_with_index do |disability, dis_idx|
          if disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].blank?
            collect_error_messages(source: "disabilities/#{dis_idx}/",
                                   detail: "If the `disabilityActionType` (#{dis_idx}) is set to `NONE` " \
                                           'there must be a secondary disability present.')
          end
          next if disability['secondaryDisabilities'].blank?

          validate_form_526_disability_secondary_disability_required_fields(disability, dis_idx)

          disability['secondaryDisabilities'].each_with_index do |secondary_disability, sd_idx|
            if secondary_disability['classificationCode'].present?
              validate_form_526_disability_secondary_disability_classification_code(secondary_disability, dis_idx,
                                                                                    sd_idx)
              validate_form_526_disability_code_enddate(secondary_disability['classificationCode'].to_i, dis_idx,
                                                        sd_idx)
            end

            if secondary_disability['approximateDate'].present?
              validate_form_526_disability_secondary_disability_approximate_begin_date(secondary_disability, dis_idx,
                                                                                       sd_idx)
            end
          end
        end
      end

      def validate_form_526_disability_secondary_disability_required_fields(disability, disability_idx)
        disability['secondaryDisabilities'].each_with_index do |secondary_disability, sd_idx|
          sd_name = secondary_disability&.dig('name')
          sd_disability_action_type = secondary_disability&.dig('disabilityActionType')
          sd_service_relevance = secondary_disability&.dig('serviceRelevance')

          form_object_desc = "/disability/#{disability_idx}/secondaryDisability/#{sd_idx}"

          collect_error_if_value_not_present('name', "#{form_object_desc}/name") if sd_name.blank?

          if sd_disability_action_type.blank?
            collect_error_if_value_not_present('disabilityActionType',
                                               "#{form_object_desc}/disabilityActionType")
          end
          if sd_service_relevance.blank?
            collect_error_if_value_not_present('service relevance',
                                               "#{form_object_desc}/serviceRelevance")
          end
        end
      end

      def validate_form_526_disability_secondary_disability_classification_code(secondary_disability, dis_idx, sd_idx)
        return if brd_classification_ids.include?(secondary_disability['classificationCode'].to_i)

        collect_error_messages(source: "disabilities/#{dis_idx}/secondaryDisabilities/#{sd_idx}/classificationCode",
                               detail: "classificationCode (#{dis_idx}) must match an active code " \
                                       'returned from the /disabilities endpoint of the Benefits Reference Data API.')
      end

      def validate_form_526_disability_secondary_disability_approximate_begin_date(secondary_disability, dis_idx,
                                                                                   sd_idx)
        return unless date_is_valid?(secondary_disability['approximateDate'],
                                     'disabilities.secondaryDisabilities.approximateDate')

        return if date_is_valid_against_current_time_after_check_on_format?(secondary_disability['approximateDate'])

        collect_error_messages(source: "/disabilities/#{dis_idx}/secondaryDisability/#{sd_idx}/approximateDate",
                               detail: "approximateDate (#{dis_idx}) must be a date in the past.")
      end

      def validate_form_526_veteran_homelessness # rubocop:disable Metrics/MethodLength
        return if form_attributes&.dig('homeless').nil? # nullable on schema

        handle_empty_other_description

        if too_many_homelessness_attributes_provided?
          collect_error_messages(source: '/homeless/',
                                 detail: "Must define only one of 'homeless/currentlyHomeless' or " \
                                         "'homeless/riskOfBecomingHomeless'")
        end

        if unnecessary_homelessness_point_of_contact_provided?
          collect_error_messages(source: '/homeless/',
                                 detail: "If 'homeless/pointOfContact' is defined, then one of " \
                                         "'homeless/currentlyHomeless' or 'homeless/riskOfBecomingHomeless'" \
                                         ' is required')
        end

        if missing_point_of_contact?
          collect_error_messages(source: '/homeless/',
                                 detail: "If one of 'homeless/currentlyHomeless' or 'homeless/riskOfBecomingHomeless'" \
                                         " is defined, then 'homeless/pointOfContact' is required")
        end

        if international_phone_too_long?
          collect_error_messages(source: '/homeless/pointOfContactNumber/internationalTelephone',
                                 detail: 'International telephone number must be shorter than 25 characters')
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

      def international_phone_too_long?
        phone = form_attributes.dig('homeless', 'pointOfContactNumber', 'internationalTelephone')
        phone.length > 25 if phone
      end

      def validate_form_526_toxic_exposure
        return if form_attributes&.dig('toxicExposure').nil? # nullable on schema

        gulf_war_service = form_attributes&.dig('toxicExposure', 'gulfWarHazardService')
        validate_form_526_toxic_exp_sections(gulf_war_service, 'gulfWarHazardService')
        herbicide_service = form_attributes&.dig('toxicExposure', 'herbicideHazardService')
        validate_form_526_toxic_exp_sections(herbicide_service, 'herbicideHazardService')
        other_exposures = form_attributes&.dig('toxicExposure', 'additionalHazardExposures')
        validate_form_526_toxic_multi_addtl_exp(other_exposures, 'additionalHazardExposures')
        multi_exposures = form_attributes&.dig('toxicExposure', 'multipleExposures')
        validate_form_526_toxic_multi_addtl_exp(multi_exposures, 'multipleExposures')
      end

      def validate_form_526_toxic_exp_sections(section, attribute_name)
        if section&.nil? || section&.dig('servedInHerbicideHazardLocations') == 'NO' ||
           section&.dig('servedInGulfWarHazardLocations') == 'NO'
          return
        end

        begin_date = section&.dig('serviceDates', 'beginDate')
        end_date = section&.dig('serviceDates', 'endDate')

        begin_prop = "/toxicExposure/#{attribute_name}/serviceDates/beginDate"
        end_prop = "/toxicExposure/#{attribute_name}/serviceDates/endDate"

        validate_service_date(begin_date, begin_prop) unless begin_date.nil? || !date_is_valid?(begin_date,
                                                                                                begin_prop, true)
        validate_service_date(end_date, end_prop) unless end_date.nil? || !date_is_valid?(end_date, end_prop, true)
      end

      def validate_form_526_toxic_multi_addtl_exp(section, attribute_name)
        return if section.nil?

        [section].flatten&.each do |item, idx|
          begin_date = item&.dig('exposureDates', 'beginDate')
          end_date = item&.dig('exposureDates', 'endDate')

          begin_prop = "/toxicExposure/#{attribute_name}/#{idx}/exposureDates/beginDate"
          end_prop = "/toxicExposure/#{attribute_name}/#{idx}/exposureDates/endDate"

          validate_service_date(begin_date, begin_prop) unless begin_date.nil? || !date_is_valid?(begin_date,
                                                                                                  begin_prop, true)
          validate_service_date(end_date, end_prop) unless end_date.nil? || !date_is_valid?(end_date, end_prop, true)
        end
      end

      def validate_service_date(date, prop)
        if date_has_day?(date) # this date should not have the day
          collect_error_messages(source: prop.to_s,
                                 detail: 'Service dates must be in the format of yyyy-mm or yyyy')
        end
      end

      def validate_form_526_service_pay
        validate_form_526_military_retired_pay
        validate_form_526_future_military_retired_pay
        validate_from_526_military_retired_pay_branch
        validate_form_526_separation_pay_received_date
        validate_from_526_separation_severance_pay_branch
      end

      def validate_form_526_military_retired_pay
        receiving_attr = form_attributes.dig('servicePay', 'receivingMilitaryRetiredPay')
        future_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPay')

        return if receiving_attr.nil?
        return unless receiving_attr == future_attr

        # EVSS does not allow both attributes to be the same value (unless that value is nil)
        collect_error_messages(source: '/servicePay/',
                               detail: "'servicePay/receivingMilitaryRetiredPay' and " \
                                       "'servicePay/futureMilitaryRetiredPay " \
                                       'should not be the same value')
      end

      def validate_from_526_military_retired_pay_branch
        return if form_attributes.dig('servicePay', 'militaryRetiredPay').nil?

        branch = form_attributes.dig('servicePay', 'militaryRetiredPay', 'branchOfService')
        return if branch.nil? || brd_service_branch_names.include?(branch)

        collect_error_messages(source: '/servicePay/militaryRetiredPay/branchOfService',
                               detail: "'servicePay.militaryRetiredPay.branchOfService' must match a service branch " \
                                       'returned from the /service-branches endpoint of the Benefits ' \
                                       'Reference Data API.')
      end

      def validate_form_526_future_military_retired_pay
        future_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPay')
        future_explanation_attr = form_attributes.dig('servicePay', 'futureMilitaryRetiredPayExplanation')
        return if future_attr.nil?

        if future_attr == 'YES' && future_explanation_attr.blank?
          collect_error_messages(source: '/servicePay/',
                                 detail: "If 'servicePay/futureMilitaryRetiredPay' is true, then " \
                                         "'servicePay/futureMilitaryRetiredPayExplanation' is required")
        end
      end

      def validate_form_526_separation_pay_received_date
        separation_pay_received_date = form_attributes.dig('servicePay', 'separationSeverancePay',
                                                           'datePaymentReceived')
        return if separation_pay_received_date.blank?

        return if date_is_valid_against_current_time_after_check_on_format?(separation_pay_received_date)

        collect_error_messages(source: '/servicePay/separationSeverancePay/datePaymentReceived',
                               detail: 'datePaymentReceived must be a date in the past.')
      end

      def validate_from_526_separation_severance_pay_branch
        branch = form_attributes.dig('servicePay', 'separationSeverancePay', 'branchOfService')
        return if branch.nil? || brd_service_branch_names.include?(branch)

        collect_error_messages(source: '/servicePay/separationSeverancePay/branchOfService',
                               detail: "'servicePay/separationSeverancePay/branchOfService' must match a service " \
                                       'branch returned from the /service-branches endpoint of the Benefits ' \
                                       'Reference Data API.')
      end

      def validate_form_526_treatments
        treatments = form_attributes['treatments']
        return if treatments.blank?

        validate_treatment_dates(treatments)
      end

      def valid_treatment_date?(first_service_date, treatment_begin_date)
        return true if first_service_date.blank? || treatment_begin_date.nil?

        case type_of_date_format(treatment_begin_date)
        when 'yyyy-mm'
          first_service_date = Date.new(first_service_date.year, first_service_date.month, 1)
          treatment_begin_date = Date.strptime(treatment_begin_date, '%Y-%m')
        when 'yyyy'
          first_service_date = Date.new(first_service_date.year, 1, 1)
          treatment_begin_date = Date.strptime(treatment_begin_date, '%Y')
        else
          return false
        end

        first_service_date <= treatment_begin_date
      end

      def validate_treatment_dates(treatments) # rubocop:disable Metrics/MethodLength
        first_service_period = form_attributes['serviceInformation']['servicePeriods'].min_by do |per|
          per['activeDutyBeginDate']
        end

        first_service_date = if first_service_period['activeDutyBeginDate'] &&
                                date_is_valid?(
                                  first_service_period['activeDutyBeginDate'],
                                  'serviceInformation/servicePeriods/activeDutyBeginDate',
                                  true
                                )
                               Date.strptime(first_service_period['activeDutyBeginDate'], '%Y-%m-%d')
                             end

        treatments.each_with_index do |treatment, idx|
          treatment_begin_date = treatment['beginDate']

          next if treatment_begin_date.nil?

          next unless date_is_valid?(treatment_begin_date, "/treatments/#{idx}/beginDate")

          next if valid_treatment_date?(first_service_date, treatment_begin_date)

          collect_error_messages(
            source: "/treatments/#{idx}/beginDate",
            detail: "Each treatment begin date (#{idx}) must be after the first activeDutyBeginDate"
          )
        end
      end

      def validate_form_526_service_information(target_veteran)
        service_information = form_attributes['serviceInformation']

        return if service_information.nil? || service_information.blank?

        validate_claim_date_to_active_duty_end_date(service_information)
        validate_service_periods(service_information, target_veteran)
        validate_service_branch_names(service_information)
        validate_confinements(service_information)
        validate_alternate_names(service_information)
        validate_reserves_required_values(service_information)
        validate_form_526_location_codes(service_information)
      end

      def validate_claim_date_to_active_duty_end_date(service_information)
        ant_sep_date = form_attributes&.dig('serviceInformation', 'federalActivation', 'anticipatedSeparationDate')
        unless service_information['servicePeriods'].nil?
          max_period = service_information['servicePeriods'].max_by { |sp| sp['activeDutyEndDate'] }
        end
        max_active_duty_end_date = max_period['activeDutyEndDate']

        max_date_valid = date_is_valid?(max_active_duty_end_date,
                                        'serviceInformation/servicePeriods/activeDutyBeginDate', true)

        return if max_date_valid || max_period&.dig('activeDutyEndDate').nil? || ant_sep_date.nil?

        if ant_sep_date.present? && max_active_duty_end_date.present? && max_date_valid && ((Date.strptime(
          max_period['activeDutyEndDate'], '%Y-%m-%d'
        ) > Date.strptime(CLAIM_DATE.to_s, '%Y-%m-%d') +
           180.days) || (Date.strptime(ant_sep_date,
                                       '%Y-%m-%d') > Date.strptime(CLAIM_DATE.to_s, '%Y-%m-%d') + 180.days))

          collect_error_messages(
            detail: 'Service members cannot submit a claim until they are within 180 days of their separation date.'
          )
        end
      end

      def validate_service_periods(service_information, target_veteran)
        date_of_birth = Date.strptime(target_veteran.birth_date, '%Y%m%d')
        age_thirteen = date_of_birth.next_year(13)
        service_information['servicePeriods'].each_with_index do |sp, idx|
          if sp['activeDutyBeginDate']
            next unless date_is_valid?(sp['activeDutyBeginDate'],
                                       'serviceInformation/servicePeriods/activeDutyBeginDate', true)

            age_exception(idx) if Date.strptime(sp['activeDutyBeginDate'], '%Y-%m-%d') <= age_thirteen

            if sp['activeDutyEndDate']
              next unless date_is_valid?(sp['activeDutyEndDate'],
                                         'serviceInformation/servicePeriods/activeDutyBeginDate', true)

              if Date.strptime(sp['activeDutyBeginDate'], '%Y-%m-%d') > Date.strptime(
                sp['activeDutyEndDate'], '%Y-%m-%d'
              )
                begin_date_exception(idx)
              end
            end
          end
        end
      end

      def age_exception(idx)
        collect_error_messages(
          source: "/serviceInformation/servicePeriods/#{idx}/activeDutyBeginDate",
          detail: "Active Duty Begin Date (#{idx}) cannot be on or before Veteran's thirteenth birthday."
        )
      end

      def begin_date_exception(idx)
        collect_error_messages(
          source: "/serviceInformation/servicePeriods/#{idx}/activeDutyEndDate",
          detail: "activeDutyEndDate (#{idx}) needs to be after activeDutyBeginDate."
        )
      end

      def validate_form_526_location_codes(service_information) # rubocop:disable Metrics/MethodLength
        service_periods = service_information['servicePeriods']
        any_code_present = service_periods.any? do |service_period|
          service_period['separationLocationCode'].present?
        end

        # only retrieve separation locations if we'll need them
        return unless any_code_present

        separation_locations = retrieve_separation_locations

        if separation_locations.nil?
          collect_error_messages(
            detail: 'The Reference Data Service is unavailable to verify the separation location code for the claimant'
          )
          return
        end

        separation_location_ids = separation_locations.pluck(:id).to_set(&:to_s)

        service_periods.each_with_index do |service_period, idx|
          separation_location_code = service_period['separationLocationCode']

          next if separation_location_code.nil? || separation_location_ids.include?(separation_location_code)

          ClaimsApi::Logger.log('separation_location_codes', detail: 'Separation location code not found',
                                                             separation_locations:, separation_location_code:)

          collect_error_messages(
            source: "/serviceInformation/servicePeriods/#{idx}/separationLocationCode",
            detail: "The separation location code (#{idx}) for the claimant is not a valid value."
          )
        end
      end

      def validate_confinements(service_information) # rubocop:disable Metrics/MethodLength
        confinements = service_information&.dig('confinements')

        return if confinements.blank?

        confinements.each_with_index do |confinement, idx|
          approximate_begin_date = confinement&.dig('approximateBeginDate')
          approximate_end_date = confinement&.dig('approximateEndDate')

          form_object_desc = "/confinement/#{idx}"
          if approximate_begin_date.blank?
            collect_error_if_value_not_present('approximate begin date',
                                               "#{form_object_desc}/approximateBeginDate")
          end
          if approximate_end_date.blank?
            collect_error_if_value_not_present('approximate end date',
                                               "#{form_object_desc}/approximateEndDate")
          end

          next if approximate_begin_date.blank? || approximate_end_date.blank?
          next unless date_is_valid?(approximate_begin_date,
                                     "#{form_object_desc}/approximateBeginDate") &&
                      date_is_valid?(approximate_end_date, "#{form_object_desc}/approximateEndDate")

          if begin_date_is_after_end_date?(approximate_begin_date, approximate_end_date)
            collect_error_messages(
              source: "/confinements/#{idx}/",
              detail: "Confinement approximate end date (#{idx}) must be after approximate begin date."
            )
          end

          service_periods = service_information&.dig('servicePeriods')
          earliest_active_duty_begin_date = find_earliest_active_duty_begin_date(service_periods)

          next if earliest_active_duty_begin_date['activeDutyBeginDate'].blank? # nothing to check against below
          next unless date_is_valid?(earliest_active_duty_begin_date['activeDutyBeginDate'],
                                     'serviceInformation/servicePeriods/activeDutyBeginDate', true)

          # if confinementBeginDate is before earliest activeDutyBeginDate, raise error
          if duty_begin_date_is_after_approximate_begin_date?(earliest_active_duty_begin_date['activeDutyBeginDate'],
                                                              approximate_begin_date)
            collect_error_messages(
              source: "/confinements/#{idx}/approximateBeginDate",
              detail: "Confinement approximate begin date (#{idx}) must be after earliest active duty begin date."
            )
          end

          @ranges ||= []
          @ranges << (date_regex_groups(approximate_begin_date)..date_regex_groups(approximate_end_date))
          if overlapping_confinement_periods?(idx)
            collect_error_messages(
              source: "/confinements/#{idx}/approximateBeginDate",
              detail: "Confinement periods (#{idx}) may not overlap each other."
            )
          end
          unless confinement_dates_are_within_service_period?(approximate_begin_date, approximate_end_date,
                                                              service_periods)
            collect_error_messages(
              source: "/confinements/#{idx}",
              detail: "Confinement dates (#{idx}) must be within one of the service period dates."
            )
          end
        end
      end

      def confinement_dates_are_within_service_period?(approximate_begin_date, approximate_end_date, service_periods) # rubocop:disable Metrics/MethodLength
        within_service_period = false
        service_periods.each do |sp|
          next unless date_is_valid?(sp['activeDutyBeginDate'],
                                     'serviceInformation/servicePeriods/activeDutyBeginDate', true) &&
                      date_is_valid?(sp['activeDutyEndDate'], 'serviceInformation/servicePeriods/activeDutyEndDate',
                                     true)

          active_duty_begin_date = Date.strptime(sp['activeDutyBeginDate'], '%Y-%m-%d') if sp['activeDutyBeginDate']
          active_duty_end_date = Date.strptime(sp['activeDutyEndDate'], '%Y-%m-%d') if sp['activeDutyEndDate']

          next if active_duty_begin_date.blank? || active_duty_end_date.blank? # nothing to compare against

          begin_date_has_day = date_has_day?(approximate_begin_date)
          end_date_has_day = date_has_day?(approximate_end_date)
          begin_date = if begin_date_has_day
                         Date.strptime(approximate_begin_date, '%Y-%m-%d')
                       else
                         # Note approximate date conversion sets begin date to first of month
                         Date.strptime(approximate_begin_date, '%Y-%m')
                       end

          end_date = if end_date_has_day
                       Date.strptime(approximate_end_date, '%Y-%m-%d')
                     else
                       # Set approximate end date to end of month
                       Date.strptime(approximate_end_date, '%Y-%m').end_of_month
                     end

          if date_is_within_range?(begin_date, end_date, active_duty_begin_date, active_duty_end_date)
            within_service_period = true
          end
        end
        within_service_period
      end

      def date_is_within_range?(conf_begin, conf_end, service_begin, service_end)
        return if service_begin.blank? || service_end.blank?

        conf_begin.between?(service_begin, service_end) &&
          conf_end.between?(service_begin, service_end)
      end

      def validate_alternate_names(service_information) # rubocop:disable Metrics/MethodLength
        alternate_names = service_information&.dig('alternateNames')

        # if alternate names is an empty array, stub it to be nil
        if alternate_names.is_a?(Array) && alternate_names.empty?
          form_attributes['serviceInformation']['alternateNames'] = nil
          return
        end

        return if alternate_names.blank?

        # validate each name against regex
        alternate_names.each_with_index do |name, idx|
          unless name.match?(Regexp.new(ALT_NAMES_REGEX))
            collect_error_messages(
              source: "/serviceInformation/alternateNames/#{idx}",
              detail: "Alternate name (#{idx}) contains invalid characters. " \
                      'Must match the following regex: ' \
                      "#{ALT_NAMES_REGEX}"
            )
          end
        end

        # clean them up to compare
        alternate_names = alternate_names.map(&:strip).map(&:downcase)

        # returns nil unless there are duplicate names
        duplicate_names_check = alternate_names.detect { |e| alternate_names.rindex(e) != alternate_names.index(e) }

        unless duplicate_names_check.nil?
          collect_error_messages(
            source: '/serviceInformation/alternateNames',
            detail: 'Names entered as an alternate name must be unique.'
          )
        end
      end

      def validate_service_branch_names(service_information)
        downcase_branches = brd_service_branch_names.map(&:downcase)
        service_information['servicePeriods'].each_with_index do |sp, idx|
          unless downcase_branches.include?(sp['serviceBranch'].downcase)
            collect_error_messages(
              source: "/serviceInformation/servicePeriods/#{idx}/serviceBranch",
              detail: "serviceBranch (#{idx}) must match a service branch " \
                      'returned from the /service-branches endpoint of the Benefits ' \
                      'Reference Data API.' \
            )
          end
        end
      end

      def validate_reserves_required_values(service_information)
        validate_federal_activation_values(service_information)
        reserves = service_information&.dig('reservesNationalGuardService')

        return if reserves.blank?

        # if reserves is not empty the we require tos dates
        validate_reserves_tos_dates(reserves)
      end

      def validate_reserves_tos_dates(reserves)
        tos = reserves&.dig('obligationTermsOfService')
        return if tos.blank?

        tos_start_date = tos&.dig('beginDate')
        tos_end_date = tos&.dig('endDate')

        form_obj_desc = 'obligation terms of service'

        # if one is present both need to be present
        if tos_start_date.blank? && tos_end_date.present?
          collect_error_if_value_not_present('begin date', form_obj_desc)
        end
        if tos_end_date.blank? && tos_start_date.present?
          collect_error_if_value_not_present('end date',
                                             form_obj_desc)
        end
        if tos_start_date.present? && tos_end_date.present? && (Date.strptime(tos_start_date,
                                                                              '%Y-%m-%d') > Date.strptime(tos_end_date,
                                                                                                          '%Y-%m-%d'))
          collect_error_messages(
            detail: 'Terms of service begin date must be before the terms of service end date.',
            source: '/serviceInformation/reservesNationalGuardService/obligationTermsOfService'
          )
        end
      end

      def validate_federal_activation_values(service_information)
        federal_activation = service_information&.dig('federalActivation')
        federal_activation_date = federal_activation&.dig('activationDate')
        anticipated_separation_date = federal_activation&.dig('anticipatedSeparationDate')

        return if federal_activation.blank?

        form_obj_desc = '/serviceInformation/federalActivation'

        # For a valid BDD EP code to be assigned we need these values
        validate_required_values_for_federal_activation(federal_activation_date, anticipated_separation_date)

        validate_federal_activation_date(federal_activation_date, form_obj_desc)

        validate_federal_activation_date_order(federal_activation_date) if federal_activation_date.present?
        if anticipated_separation_date.present?
          validate_anticipated_separation_date_in_past(anticipated_separation_date)
        end
      end

      def validate_federal_activation_date(federal_activation_date, form_obj_desc)
        if federal_activation_date.blank?
          collect_error_if_value_not_present('federal activation date',
                                             form_obj_desc)
        end
      end

      def validate_federal_activation_date_order(federal_activation_date)
        # we know the dates are present
        if activation_date_not_after_duty_begin_date?(federal_activation_date)
          collect_error_messages(
            source: '/serviceInformation/federalActivation/',
            detail: 'The federalActivation date must be after the earliest service period active duty begin date.'
          )
        end
      end

      def validate_required_values_for_federal_activation(activation_date, separation_date) # rubocop:disable Metrics/MethodLength
        activation_form_obj_desc = 'serviceInformation/federalActivation/'
        reserves_dates_form_obj_desc = 'serviceInformation/reservesNationalGuardService/obligationTermsOfService/'
        reserves_unit_form_obj_desc = 'serviceInformation/reservesNationalGuardService/'

        reserves = form_attributes.dig('serviceInformation', 'reservesNationalGuardService')
        tos_start_date = reserves&.dig('obligationTermsOfService', 'beginDate')
        tos_end_date = reserves&.dig('obligationTermsOfService', 'endDate')
        unit_name = reserves&.dig('unitName')

        if activation_date.blank?
          collect_error_messages(detail: 'activationDate is missing or blank',
                                 source: activation_form_obj_desc)
        end
        if separation_date.blank?
          collect_error_messages(detail: 'anticipatedSeparationDate is missing or blank',
                                 source: activation_form_obj_desc)
        end
        if tos_start_date.blank?
          collect_error_messages(detail: 'beginDate is missing or blank',
                                 source: reserves_dates_form_obj_desc)
        end
        if tos_end_date.blank?
          collect_error_messages(detail: 'endDate is missing or blank',
                                 source: reserves_dates_form_obj_desc)
        end
        if unit_name.blank?
          collect_error_messages(detail: 'unitName is missing or blank',
                                 source: reserves_unit_form_obj_desc)
        end
      end

      def activation_date_not_after_duty_begin_date?(activation_date)
        service_information = form_attributes['serviceInformation']
        service_periods = service_information&.dig('servicePeriods')

        earliest_active_duty_begin_date = find_earliest_active_duty_begin_date(service_periods)

        # return true if activationDate is an earlier date
        return unless date_is_valid?(earliest_active_duty_begin_date['activeDutyBeginDate'],
                                     'serviceInformation/servicePeriods/activeDutyEndDate', true)

        return false if earliest_active_duty_begin_date['activeDutyBeginDate'].nil?

        if activation_date.blank?
          collect_error_messages(
            source: '/serviceInformation/federalActivation/',
            detail: 'The activationDate must be present for federalActivation.'
          )
        else
          Date.parse(activation_date) < Date.strptime(earliest_active_duty_begin_date['activeDutyBeginDate'],
                                                      '%Y-%m-%d')
        end
      end

      def find_earliest_active_duty_begin_date(service_periods)
        service_periods.min_by do |a|
          next unless date_is_valid?(a['activeDutyBeginDate'],
                                     'servicePeriod/activeDutyBeginDate', true)

          Date.strptime(a['activeDutyBeginDate'], '%Y-%m-%d') if a['activeDutyBeginDate']
        end
      end

      def validate_anticipated_separation_date_in_past(date)
        return if date.blank?

        if Date.strptime(date, '%Y-%m-%d') < Time.zone.now
          collect_error_messages(
            source: '/serviceInformation/federalActivation/',
            detail: 'The anticipated separation date must be a date in the future.'
          )
        end
      end

      def validate_form_526_direct_deposit
        direct_deposit = form_attributes['directDeposit']
        return if direct_deposit.blank?

        account_check = direct_deposit&.dig('noAccount')

        account_check.present? && account_check == true ? validate_no_account : validate_account_values
      end

      def validate_no_account
        acc_vals = form_attributes['directDeposit']

        collect_error_on_invalid_account_values('accountType') if acc_vals['accountType'].present?
        collect_error_on_invalid_account_values('accountNumber') if acc_vals['accountNumber'].present?
        collect_error_on_invalid_account_values('routingNumber') if acc_vals['routingNumber'].present?
        if acc_vals['financialInstitutionName'].present?
          collect_error_on_invalid_account_values('financialInstitutionName')
        end
      end

      def collect_error_on_invalid_account_values(account_detail)
        collect_error_messages(
          source: "/directDeposit/#{account_detail}",
          detail: "If the claimant has no account the #{account_detail} field must be left empty."
        )
      end

      def validate_account_values
        direct_deposit_account_vals = form_attributes['directDeposit']
        return if direct_deposit_account_vals['noAccount']

        valid_account_types = %w[CHECKING SAVINGS]
        account_type = direct_deposit_account_vals&.dig('accountType')
        account_number = direct_deposit_account_vals&.dig('accountNumber')
        routing_number = direct_deposit_account_vals&.dig('routingNumber')

        if account_type.blank? || valid_account_types.exclude?(account_type)
          collect_error_messages(detail: 'accountType is missing or blank',
                                 source: '/directDeposit/accountType')
        end
        if account_number.blank?
          collect_error_messages(detail: 'accountNumber is missing or blank',
                                 source: '/directDeposit/accountNumber')
        end
        if routing_number.blank?
          collect_error_messages(detail: 'routingNumber is missing or blank',
                                 source: '/directDeposit/routingNumber')
        end
      end

      def collect_error_if_value_not_present(val, form_obj_description)
        collect_error_messages(
          detail: "The #{val} is required for #{form_obj_description}.",
          source: form_obj_description
        )
      end

      def validate_claim_process_type_bdd
        claim_date = Date.parse(CLAIM_DATE.to_s)
        service_information = form_attributes['serviceInformation']
        active_dates = service_information['servicePeriods']&.pluck('activeDutyEndDate')
        active_dates << service_information&.dig('federalActivation', 'anticipatedSeparationDate')

        unless active_dates.compact.any? do |a|
          next unless date_is_valid?(a, 'serviceInformation/servicePeriods/activeDutyEndDate', true)

          Date.strptime(a, '%Y-%m-%d').between?(claim_date.next_day(BDD_LOWER_LIMIT),
                                                claim_date.next_day(BDD_UPPER_LIMIT))
        end
          collect_error_messages(
            source: '/serviceInformation/servicePeriods/',
            detail: "Must have an activeDutyEndDate or anticipatedSeparationDate between #{BDD_LOWER_LIMIT}" \
                    " & #{BDD_UPPER_LIMIT} days from claim date."
          )
        end
      end

      def bdd_claim?
        claim_process_type = form_attributes['claimProcessType']
        claim_process_type == 'BDD_PROGRAM'
      end

      # Either date could be in MM-YYYY or MM-DD-YYYY format
      def begin_date_after_end_date_with_mixed_format_dates?(begin_date, end_date)
        # figure out if either has the day and remove it to compare
        if type_of_date_format(begin_date) == 'yyyy-mm-dd'
          begin_date = remove_chars(begin_date.dup)
        elsif type_of_date_format(end_date) == 'yyyy-mm-dd'
          end_date = remove_chars(end_date.dup)
        end
        Date.strptime(begin_date, '%Y-%m') > Date.strptime(end_date, '%Y-%m') # only > is an issue
      end

      def date_is_valid_against_current_time_after_check_on_format?(date)
        case type_of_date_format(date)
        when 'yyyy-mm-dd'
          param_date = Date.strptime(date, '%Y-%m-%d')
          now_date = Date.strptime(Time.zone.today.strftime('%Y-%m-%d'), '%Y-%m-%d')
        when 'yyyy-mm'
          param_date = Date.strptime(date, '%Y-%m')
          now_date = Date.strptime(Time.zone.today.strftime('%Y-%m'), '%Y-%m')
          now_date.end_of_month
        when 'yyyy'
          param_date = Date.strptime(date, '%Y')
          now_date = Date.strptime(Time.zone.today.strftime('%Y'), '%Y')
        end
        param_date <= now_date # Since it is approximate we go with <=
      end

      # just need to know if day is present or not
      def date_has_day?(date)
        !date.match(YYYY_YYYYMM_REGEX)
      end

      # which of the three types are we dealing with
      def type_of_date_format(date)
        DATE_FORMATS[date.length]
      end

      # removing the -DD from a YYYY-MM-DD date format to compare against a YYYY-MM date
      def remove_chars(str)
        str.sub(/-\d{2}\z/, '')
      end

      def date_regex_groups(date)
        date_object = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength

        make_date_string(date_object, date.length)
      end

      def make_date_string(date_object, date_length)
        return if date_object.nil? || date_length.zero?

        if date_length == 4
          "#{date_object[:year]}-01-01".to_date
        elsif date_length == 7
          "#{date_object[:year]}-#{date_object[:month]}-01".to_date.end_of_month
        else
          "#{date_object[:year]}-#{date_object[:month]}-#{date_object[:day]}".to_date
        end
      end

      def begin_date_is_after_end_date?(begin_date, end_date)
        date_regex_groups(begin_date) > date_regex_groups(end_date)
      end

      def duty_begin_date_is_after_approximate_begin_date?(begin_date, approximate_begin_date)
        return unless date_is_valid?(begin_date, 'serviceInformation/servicePeriods/activeDutyEndDate', true)

        date_regex_groups(begin_date) > date_regex_groups(approximate_begin_date)
      end

      def overlapping_confinement_periods?(idx)
        return if @ranges&.size&.<= 1

        range_one = @ranges[idx - 1]
        range_two = @ranges[idx]
        range_one.present? && range_two.present? ? date_range_overlap?(range_one, range_two) : return
      end

      def date_range_overlap?(range_one, range_two)
        return if range_one.last.nil? || range_one.first.nil? || range_two.last.nil? || range_two.first.nil?

        (range_one&.last&.> range_two&.first) || (range_two&.last&.< range_one&.first)
      end

      # Will check for a real date including leap year
      def date_is_valid?(date, property, is_full_date = false) # rubocop:disable Style/OptionalBooleanParameter
        return false if date.blank?

        collect_date_error(date, property) unless /^[\d-]+$/ =~ date # check for something like 'July 2017'

        return false if is_full_date && !date.match(YYYY_MM_DD_REGEX)

        return true if date.match(YYYY_YYYYMM_REGEX) # valid YYYY or YYYY-MM date

        date_y, date_m, date_d = date.split('-').map(&:to_i)

        return true if Date.valid_date?(date_y, date_m, date_d)

        collect_date_error(date, property)

        false
      end

      def collect_date_error(date, property = '/')
        collect_error_messages(
          detail: "#{date} is not a valid date.",
          source: "data/attributes/#{property}"
        )
      end

      def errors_array
        @errors ||= []
      end

      def collect_error_messages(detail: 'Missing or invalid attribute', source: '/',
                                 title: 'Unprocessable Entity', status: '422')
        errors_array.push({ detail:, source:, title:, status: })
      end

      def error_collection
        errors_array.uniq! { |e| e[:detail] }
        errors_array # set up the object to match other error returns
      end
    end
  end
end
