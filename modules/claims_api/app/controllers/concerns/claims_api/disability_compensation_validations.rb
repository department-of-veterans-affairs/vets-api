# frozen_string_literal: true

require 'common/exceptions'

module ClaimsApi
  module DisabilityCompensationValidations # rubocop:disable Metrics/ModuleLength
    #
    # Any custom 526 submission validations above and beyond json schema validation
    #
    def validate_form_526_submission_values!
      # ensure 'claimDate', if provided, is a valid date not in the future
      validate_form_526_submission_claim_date!
      # ensure 'applicationExpirationDate', if provided, is a valid date less than or equal to the current day
      validate_form_526_application_expiration_date!
      # ensure 'claimantCertification' is true
      validate_form_526_claimant_certification!
      # ensure any provided 'separationLocationCode' values are valid EVSS ReferenceData values
      validate_form_526_location_codes!
      # ensure any provided 'confinements' are within a provided 'servicePeriod' and do not overlap other 'confinements'
      validate_form_526_service_information_confinements!
      # ensure conflicting homelessness values are not provided
      validate_form_526_veteran_homelessness!
      # ensure 'militaryRetiredPay.receiving' and 'militaryRetiredPay.willReceiveInFuture' are not same non-null values
      validate_form_526_service_pay!
      # ensure 'title10ActivationDate' if provided, is after the earliest servicePeriod.activeDutyBeginDate and on or before the current date # rubocop:disable Layout/LineLength
      validate_form_526_title10_activation_date!
      # ensure 'title10Activation.anticipatedSeparationDate' is in the future
      validate_form_526_title10_anticipated_separation_date!
      # ensure 'currentMailingAddress' attributes are valid
      validate_form_526_current_mailing_address!
      # ensure 'changeOfAddress.beginningDate' is in the future if 'addressChangeType' is 'TEMPORARY'
      validate_form_526_change_of_address!
      # ensure any provided 'disability.classificationCode' is a known value in BGS
      # ensure any provided 'disability.approximateBeginDate' is in the past
      # ensure a 'disability.specialIssue' of 'HEPC' has a `disability.name` of 'hepatitis'
      # ensure a 'disability.specialIssue' of 'POW' has a valid 'serviceInformation.confinement'
      # ensure any provided 'disability.secondaryDisabilities.classificationCode' is a known value in BGS
      # ensure any provided 'disability.secondaryDisabilities.classificationCode' equals 'disability.secondaryDisabilities.name' # rubocop:disable Layout/LineLength
      # ensure any provided 'disability.secondaryDisabilities.name' is <= 255 characters in length
      # ensure any provided 'disability.secondaryDisabilities.approximateBeginDate' is in the past
      validate_form_526_disabilities!
      # ensure any provided 'treatment.startDate' is after the earliest 'servicePeriods.activeDutyBeginDate'
      # ensure the 'treatment.endDate' is after the 'treatment.startDate'
      # ensure any provided 'treatment.treatedDisabilityNames' match a provided 'disabilities.name'
      validate_form_526_treatments!
    end

    def validate_form_526_current_mailing_address!
      validate_form_526_current_mailing_address_country!
    end

    def validate_form_526_current_mailing_address_country!
      current_mailing_address = form_attributes.dig('veteran', 'currentMailingAddress')

      return if valid_countries.include?(current_mailing_address['country'])

      raise ::Common::Exceptions::InvalidFieldValue.new('country', current_mailing_address['country'])
    end

    def valid_countries
      @current_user.last_signed_in = Time.now.iso8601 if @current_user.last_signed_in.blank?
      @valid_countries ||= EVSS::ReferenceData::Service.new(@current_user).get_countries.countries
    end

    def validate_form_526_change_of_address!
      validate_form_526_change_of_address_beginning_date!
      validate_form_526_change_of_address_country!
    end

    def validate_form_526_change_of_address_beginning_date!
      change_of_address = form_attributes.dig('veteran', 'changeOfAddress')
      return if change_of_address.blank?
      return unless 'TEMPORARY'.casecmp?(change_of_address['addressChangeType'])
      return if Date.parse(change_of_address['beginningDate']) > Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('beginningDate', change_of_address['beginningDate'])
    end

    def validate_form_526_change_of_address_country!
      change_of_address = form_attributes.dig('veteran', 'changeOfAddress')
      return if change_of_address.blank?
      return if valid_countries.include?(change_of_address['country'])

      raise ::Common::Exceptions::InvalidFieldValue.new('country', change_of_address['country'])
    end

    def validate_form_526_title10_activation_date!
      title10_activation_date = form_attributes.dig('serviceInformation',
                                                    'reservesNationalGuardService',
                                                    'title10Activation',
                                                    'title10ActivationDate')
      return if title10_activation_date.blank?

      begin_dates = form_attributes['serviceInformation']['servicePeriods'].map do |service_period|
        Date.parse(service_period['activeDutyBeginDate'])
      end

      return if Date.parse(title10_activation_date) > begin_dates.min &&
                Date.parse(title10_activation_date) <= Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('title10ActivationDate', title10_activation_date)
    end

    def validate_form_526_title10_anticipated_separation_date!
      title10_anticipated_separation_date = form_attributes.dig('serviceInformation',
                                                                'reservesNationalGuardService',
                                                                'title10Activation',
                                                                'anticipatedSeparationDate')

      return if title10_anticipated_separation_date.blank?

      return if Date.parse(title10_anticipated_separation_date) > Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new(
        'anticipatedSeparationDate',
        title10_anticipated_separation_date
      )
    end

    def validate_form_526_submission_claim_date!
      return if form_attributes['claimDate'].blank?
      return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
    end

    def validate_form_526_application_expiration_date!
      return if form_attributes['applicationExpirationDate'].blank?
      return if Date.parse(form_attributes['applicationExpirationDate']) > Time.zone.today

      raise ::Common::Exceptions::InvalidFieldValue.new('applicationExpirationDate',
                                                        form_attributes['applicationExpirationDate'])
    end

    def validate_form_526_claimant_certification!
      return unless form_attributes['claimantCertification'] == false

      raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                        form_attributes['claimantCertification'])
    end

    def validate_form_526_location_codes!
      # only retrieve separation locations if we'll need them
      need_locations = form_attributes['serviceInformation']['servicePeriods'].detect do |service_period|
        Date.parse(service_period['activeDutyEndDate']) > Time.zone.today
      end
      separation_locations = retrieve_separation_locations if need_locations

      form_attributes['serviceInformation']['servicePeriods'].each do |service_period|
        next if Date.parse(service_period['activeDutyEndDate']) <= Time.zone.today
        next if separation_locations.any? do |location|
                  location['code'] == service_period['separationLocationCode']
                end

        raise ::Common::Exceptions::InvalidFieldValue.new('separationLocationCode',
                                                          form_attributes['separationLocationCode'])
      end
    end

    def retrieve_separation_locations
      @current_user.last_signed_in = Time.now.iso8601 if @current_user.last_signed_in.blank?
      locations_response = EVSS::ReferenceData::Service.new(@current_user).get_separation_locations
      locations_response.separation_locations
    end

    def validate_form_526_service_information_confinements!
      confinements = form_attributes['serviceInformation']['confinements']
      service_periods = form_attributes['serviceInformation']['servicePeriods']

      return if confinements.nil?

      within_service_periods_check = confinements_within_service_periods?(confinements, service_periods)
      not_overlapping_check        = confinements_dont_overlap?(confinements)
      return if within_service_periods_check && not_overlapping_check

      error_message = if within_service_periods_check
                        'confinements must not overlap other confinements'
                      else
                        'confinements must be within a service period'
                      end

      raise ::Common::Exceptions::InvalidFieldValue.new(error_message, confinements)
    end

    def confinements_within_service_periods?(confinements, service_periods)
      confinements.each do |confinement|
        next if service_periods.any? do |service_period|
          active_duty_start = Date.parse(service_period['activeDutyBeginDate'])
          active_duty_end = Date.parse(service_period['activeDutyEndDate'])
          time_range = active_duty_start..active_duty_end

          time_range.cover?(Date.parse(confinement['confinementBeginDate'])) &&
          time_range.cover?(Date.parse(confinement['confinementEndDate']))
        end

        return false
      end

      true
    end

    def confinements_dont_overlap?(confinements)
      return true if confinements.length < 2

      confinements.combination(2) do |combo|
        range1 = Date.parse(combo[0]['confinementBeginDate'])..Date.parse(combo[0]['confinementEndDate'])
        range2 = Date.parse(combo[1]['confinementBeginDate'])..Date.parse(combo[1]['confinementEndDate'])
        return false if range1.overlaps?(range2)
      end

      true
    end

    def validate_form_526_veteran_homelessness!
      if too_many_homelessness_attributes_provided?
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "Must define only one of 'veteran.homelessness.currentlyHomeless' or "\
                  "'veteran.homelessness.homelessnessRisk'"
        )
      end

      if unnecessary_homelessness_point_of_contact_provided?
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "If 'veteran.homelessness.pointOfContact' is defined, then one of "\
                  "'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk' is required"
        )
      end

      if missing_point_of_contact?
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "If one of 'veteran.homelessness.currentlyHomeless' or 'veteran.homelessness.homelessnessRisk' is "\
                  "defined, then 'veteran.homelessness.pointOfContact' is required"
        )
      end
    end

    def validate_form_526_service_pay!
      validate_form_526_military_retired_pay!
      validate_form_526_separation_pay!
    end

    def validate_form_526_military_retired_pay!
      receiving_attr    = form_attributes.dig('servicePay', 'militaryRetiredPay', 'receiving')
      will_receive_attr = form_attributes.dig('servicePay', 'militaryRetiredPay', 'willReceiveInFuture')

      return if receiving_attr.nil? || will_receive_attr.nil?
      return unless receiving_attr == will_receive_attr

      # EVSS does not allow both attributes to be the same value (unless that value is nil)
      raise ::Common::Exceptions::InvalidFieldValue.new(
        'servicePay.militaryRetiredPay',
        form_attributes['servicePay']['militaryRetiredPay']
      )
    end

    def validate_form_526_separation_pay!
      validate_form_526_separation_pay_received_date!
    end

    def validate_form_526_separation_pay_received_date!
      separation_pay_received_date = form_attributes.dig('servicePay', 'separationPay', 'receivedDate')

      return if separation_pay_received_date.blank?

      return if Date.parse(separation_pay_received_date) < Time.zone.today

      raise ::Common::Exceptions::InvalidFieldValue.new('separationPay.receivedDate', separation_pay_received_date)
    end

    def too_many_homelessness_attributes_provided?
      currently_homeless_attr = form_attributes.dig('veteran', 'homelessness', 'currentlyHomeless')
      homelessness_risk_attr  = form_attributes.dig('veteran', 'homelessness', 'homelessnessRisk')

      # EVSS does not allow both attributes to be provided at the same time
      currently_homeless_attr.present? && homelessness_risk_attr.present?
    end

    def unnecessary_homelessness_point_of_contact_provided?
      currently_homeless_attr = form_attributes.dig('veteran', 'homelessness', 'currentlyHomeless')
      homelessness_risk_attr  = form_attributes.dig('veteran', 'homelessness', 'homelessnessRisk')
      homelessness_poc_attr   = form_attributes.dig('veteran', 'homelessness', 'pointOfContact')

      # EVSS does not allow passing a 'pointOfContact' if neither homelessness attribute is provided
      currently_homeless_attr.blank? && homelessness_risk_attr.blank? && homelessness_poc_attr.present?
    end

    def missing_point_of_contact?
      homelessness_poc_attr   = form_attributes.dig('veteran', 'homelessness', 'pointOfContact')
      currently_homeless_attr = form_attributes.dig('veteran', 'homelessness', 'currentlyHomeless')
      homelessness_risk_attr  = form_attributes.dig('veteran', 'homelessness', 'homelessnessRisk')

      # 'pointOfContact' is required when either currentlyHomeless or homelessnessRisk is provided
      homelessness_poc_attr.blank? && (currently_homeless_attr.present? || homelessness_risk_attr.present?)
    end

    def validate_form_526_disabilities!
      validate_form_526_disability_classification_code!
      validate_form_526_disability_approximate_begin_date!
      validate_form_526_special_issues!
      validate_form_526_disability_secondary_disabilities!
    end

    def validate_form_526_disability_secondary_disability_disability_action_type!(disability)
      return unless disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].blank?

      raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.secondaryDisabilities',
                                                        disability['secondaryDisabilities'])
    end

    def validate_form_526_disability_secondary_disability_classification_code!(secondary_disability)
      return unless bgs_classification_ids.exclude?(secondary_disability['classificationCode'])

      raise ::Common::Exceptions::InvalidFieldValue.new(
        'disabilities.secondaryDisabilities.classificationCode',
        secondary_disability['classificationCode']
      )
    end

    def validate_form_526_disability_secondary_disability_classification_code_matches_name!(secondary_disability)
      return unless secondary_disability['classificationCode'] != secondary_disability['name']

      raise ::Common::Exceptions::InvalidFieldValue.new(
        'disabilities.secondaryDisabilities.name',
        secondary_disability['name']
      )
    end

    def validate_form_526_disability_secondary_disability_name!(secondary_disability)
      return if %r{([a-zA-Z0-9\-'.,/()]([a-zA-Z0-9\-',. ])?)+$}.match?(secondary_disability['name']) &&
                secondary_disability['name'].length <= 255

      raise ::Common::Exceptions::InvalidFieldValue.new(
        'disabilities.secondaryDisabilities.name',
        secondary_disability['name']
      )
    end

    def validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
      return if Date.parse(secondary_disability['approximateBeginDate']) < Time.zone.today

      raise ::Common::Exceptions::InvalidFieldValue.new(
        'disabilities.secondaryDisabilities.approximateBeginDate',
        secondary_disability['approximateBeginDate']
      )
    rescue ArgumentError
      raise ::Common::Exceptions::InvalidFieldValue.new(
        'disabilities.secondaryDisabilities.approximateBeginDate',
        secondary_disability['approximateBeginDate']
      )
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
          else
            validate_form_526_disability_secondary_disability_name!(secondary_disability)
          end

          if secondary_disability['approximateBeginDate'].present?
            validate_form_526_disability_secondary_disability_approximate_begin_date!(secondary_disability)
          end
        end
      end
    end

    def validate_form_526_disability_classification_code!
      return if (form_attributes['disabilities'].pluck('classificationCode') - [nil]).blank?

      form_attributes['disabilities'].each do |disability|
        next if disability['classificationCode'].blank?
        next if bgs_classification_ids.include?(disability['classificationCode'])

        raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.classificationCode',
                                                          disability['classificationCode'])
      end
    end

    def bgs_classification_ids
      return @bgs_classification_ids if @bgs_classification_ids.present?

      contention_classification_type_codes = bgs_service.data.get_contention_classification_type_code_list
      @bgs_classification_ids = contention_classification_type_codes.pluck(:clsfcn_id)
    end

    def validate_form_526_disability_approximate_begin_date!
      disabilities = form_attributes['disabilities']
      return if disabilities.blank?

      disabilities.each do |disability|
        approx_begin_date = disability['approximateBeginDate']
        next if approx_begin_date.blank?

        next if Date.parse(approx_begin_date) < Time.zone.today

        raise ::Common::Exceptions::InvalidFieldValue.new('disability.approximateBeginDate', approx_begin_date)
      end
    end

    def validate_form_526_special_issues!
      disabilities = form_attributes['disabilities']
      return if disabilities.blank?

      disabilities.each do |disability|
        special_issues = disability['specialIssues']
        next if special_issues.blank?

        if invalid_hepatitis_c_special_issue?(special_issues:, disability:)
          message = "'disability.specialIssues' :: Claim must include a disability with the name 'hepatitis'"
          raise ::Common::Exceptions::InvalidFieldValue.new(message, special_issues)
        end

        if invalid_pow_special_issue?(special_issues:)
          message = "'disability.specialIssues' :: Claim must include valid 'serviceInformation.confinements' value"
          raise ::Common::Exceptions::InvalidFieldValue.new(message, special_issues)
        end
      end
    end

    def invalid_hepatitis_c_special_issue?(special_issues:, disability:)
      # if 'specialIssues' includes 'HEPC', then EVSS requires the disability 'name' to equal 'hepatitis'
      special_issues.include?('HEPC') && !disability['name'].casecmp?('hepatitis')
    end

    def invalid_pow_special_issue?(special_issues:)
      return false unless special_issues.include?('POW')

      # if 'specialIssues' includes 'POW', then EVSS requires there also be a 'serviceInformation.confinements'
      confinements = form_attributes['serviceInformation']['confinements']
      confinements.blank?
    end

    def validate_form_526_treatments!
      treatments = form_attributes['treatments']
      return if treatments.blank?

      validate_treatment_start_dates!
      validate_treatment_end_dates!
      validate_treated_disability_names!
      validate_treatment_center_names!
    end

    def validate_treatment_start_dates!
      treatments = form_attributes['treatments']
      return if treatments.blank?

      earliest_begin_date = form_attributes['serviceInformation']['servicePeriods'].map do |service_period|
        Date.parse(service_period['activeDutyBeginDate'])
      end.min

      treatments.each do |treatment|
        treatment_start_date = treatment['startDate']

        # 'treatment.startDate' is not required, but if it's provided it needs to be valid
        next if treatment_start_date.blank?
        next if Date.parse(treatment_start_date) > earliest_begin_date

        raise ::Common::Exceptions::InvalidFieldValue.new('treatments.startDate', treatment['startDate'])
      end
    end

    def validate_treatment_end_dates!
      treatments = form_attributes['treatments']
      return if treatments.blank?

      treatments.each do |treatment|
        next if treatment['endDate'].blank?

        treatment_start_date = Date.parse(treatment['startDate'])
        treatment_end_date   = Date.parse(treatment['endDate'])

        next if treatment_end_date > treatment_start_date

        raise ::Common::Exceptions::InvalidFieldValue.new('treatments.endDate', treatment['endDate'])
      end
    end

    def validate_treated_disability_names!
      treatments = form_attributes['treatments']
      return if treatments.blank?

      declared_disability_names = form_attributes['disabilities'].pluck('name').map(&:strip).map(&:downcase)

      treatments.each do |treatment|
        treated_disability_names = treatment['treatedDisabilityNames'].map(&:strip).map(&:downcase)
        next if treated_disability_names.all? { |name| declared_disability_names.include?(name) }

        raise ::Common::Exceptions::InvalidFieldValue.new(
          'treatments.treatedDisabilityNames',
          treatment['treatedDisabilityNames']
        )
      end
    end

    def validate_treatment_center_names!
      treatments = form_attributes['treatments']
      invalid_characters = %r{[^a-zA-Z0-9\\\-'.,/() ]}

      treatments.map do |treatment|
        name = treatment['center']['name']
        name = name.truncate(100, omission: '') if name.length > 100
        name = name.gsub(invalid_characters, '') if name.match?(invalid_characters)
        name = name.strip
        treatment['center']['name'] = name

        treatment
      end
    end
  end
end
