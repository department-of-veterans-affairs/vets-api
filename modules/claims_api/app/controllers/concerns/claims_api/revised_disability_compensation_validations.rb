# frozen_string_literal: true

require 'common/exceptions'
require 'brd/brd'
require 'bgs_service/standard_data_service'

module ClaimsApi
  module RevisedDisabilityCompensationValidations # rubocop:disable Metrics/ModuleLength
    #
    # Any custom 526 submission validations above and beyond json schema validation
    #
    def validate_form_526_submission_values!
      # ensure 'claimDate', if provided, is a valid date not in the future
      validate_form_526_submission_claim_date!
      # ensure any provided 'separationLocationCode' values are valid EVSS ReferenceData values
      validate_form_526_location_codes!
      # ensure no more than 100 service periods are provided, and begin/end dates are in order
      validate_service_periods_quantity!
      validate_service_periods_chronology!
      validate_form_526_no_active_duty_end_date_more_than_180_days_in_future!
      # ensure 'servicePeriods.activeDutyBeginDate' values are in the past
      validate_service_after_13th_birthday!
      validate_form_526_service_periods_begin_in_past!
      # ensure 'title10ActivationDate' if provided, is after the earliest servicePeriod.activeDutyBeginDate and on or before the current date # rubocop:disable Layout/LineLength
      validate_form_526_title10_activation_date!
      # ensure 'anticipatedSeparationDate' if provided, in the future and
      # occurs less than 180 days from the title10ActivationDate
      validate_form_526_title10_anticipated_separation_date!
      # ensure 'currentMailingAddress' attributes are valid
      validate_form_526_current_mailing_address!
      # ensure 'changeOfAddress.beginningDate' is in the future if 'addressChangeType' is 'TEMPORARY'
      validate_form_526_change_of_address!
      # ensure no more than 150 disabilities are provided
      # ensure any provided 'disability.classificationCode' is a known value in BGS
      # ensure any provided 'disability.approximateBeginDate' is in the past
      # ensure a 'disability.specialIssue' of 'HEPC' has a `disability.name` of 'hepatitis'
      # ensure a 'disability.specialIssue' of 'POW' has a valid 'serviceInformation.confinement'
      # ensure any provided 'disability.name' is unique across all disabilities
      validate_form_526_disabilities!
    end

    def retrieve_separation_locations
      ClaimsApi::BRD.new.intake_sites
    end

    def validate_form_526_submission_claim_date!
      return if form_attributes['claimDate'].blank?
      return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
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
          location[:id]&.to_s == service_period['separationLocationCode']
        end

        raise ::Common::Exceptions::InvalidFieldValue.new('separationLocationCode',
                                                          service_period['separationLocationCode'])
      end
    end

    def validate_form_526_service_periods_begin_in_past!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods')

      service_periods.each do |service_period|
        begin_date = service_period['activeDutyBeginDate']
        next if Date.parse(begin_date) < Time.zone.today

        raise ::Common::Exceptions::InvalidFieldValue.new('servicePeriods.activeDutyBeginDate',
                                                          "A service period's activeDutyBeginDate must be in the past")
      end
    end

    def validate_service_periods_quantity!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods')
      sp_size = service_periods.size
      if sp_size > 100
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'serviceInformation.servicePeriods',
          "Number of service periods #{sp_size} " \
          'must be less than or equal to 100'
        )
      end
    end

    def validate_service_periods_chronology!
      form_attributes.dig('serviceInformation', 'servicePeriods').each do |service_period|
        begin_date = service_period['activeDutyBeginDate']
        end_date = service_period['activeDutyEndDate']
        next if end_date.blank?

        if Date.parse(end_date) < Date.parse(begin_date)
          raise ::Common::Exceptions::InvalidFieldValue.new(
            'serviceInformation.servicePeriods',
            'Invalid service period duty dates - ' \
            'Provided service period duty dates are out of order: ' \
            "begin=#{begin_date} end=#{end_date}"
          )
        end
      end
    end

    def validate_form_526_no_active_duty_end_date_more_than_180_days_in_future!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods') || []
      return unless end_date_beyond_180_days?(service_periods)

      unless eligible_for_future_end_date?(service_periods)
        # NOTE: this error message doesn't really cover all the ways this validation could
        # fail, but for backwards compatibility, it has not been changed.
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'serviceInformation/servicePeriods/activeDutyEndDate',
          'At least one active duty end date must be within 180 days from now.'
        )
      end
    end

    def end_date_beyond_180_days?(service_periods)
      service_periods.any? do |sp|
        end_date = sp['activeDutyEndDate']
        next false if end_date.blank?

        Date.parse(end_date) > 180.days.from_now.end_of_day
      end
    end

    def validate_service_after_13th_birthday!
      service_periods = form_attributes&.dig('serviceInformation', 'servicePeriods')
      age_thirteen = auth_headers['va_eauth_birthdate'].to_datetime.next_year(13).to_date

      return if age_thirteen.nil? || service_periods.nil?

      started_before_age_thirteen = service_periods.any? do |period|
        Date.parse(period['activeDutyBeginDate']) < age_thirteen
      end
      if started_before_age_thirteen
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: "If any 'serviceInformation.servicePeriods.activeDutyBeginDate' is " \
                  "before the Veteran's 13th birthdate: #{age_thirteen}, the claim can not be processed."
        )
      end
    end

    def eligible_for_future_end_date?(service_periods)
      reserves_national_guard_service = form_attributes.dig('serviceInformation', 'reservesNationalGuardService')
      reserves_national_guard_service.present? && past_service_period?(service_periods)
    end

    def past_service_period?(service_periods)
      service_periods.any? do |sp|
        end_date = sp['activeDutyEndDate']
        next false if end_date.blank?

        Date.parse(end_date) <= Time.zone.today.end_of_day
      end
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
      anticipated_separation_date = form_attributes.dig('serviceInformation',
                                                        'reservesNationalGuardService',
                                                        'title10Activation',
                                                        'anticipatedSeparationDate')
      return if anticipated_separation_date.blank?

      # validate anticipated_separation_date is in the future
      if Date.parse(anticipated_separation_date) <= Time.zone.today
        raise ::Common::Exceptions::InvalidFieldValue.new('anticipatedSeparationDate', anticipated_separation_date)
      end

      title10_activation_date = form_attributes.dig('serviceInformation',
                                                    'reservesNationalGuardService',
                                                    'title10Activation',
                                                    'title10ActivationDate')
      # validate anticipated_separation_date is within 180 days of title10_activation_date
      begin
        if title10_activation_date.present? &&
           Date.parse(anticipated_separation_date) > (Date.parse(title10_activation_date) + 180.days)
          raise ::Common::Exceptions::InvalidFieldValue.new('anticipatedSeparationDate', anticipated_separation_date)
        end
      # overkill rescue for Date.parse above
      rescue ArgumentError
        raise ::Common::Exceptions::InvalidFieldValue.new('title10ActivationDate', title10_activation_date)
      end
    end

    def valid_countries
      @valid_countries ||= ClaimsApi::BRD.new.countries
    end

    def validate_form_526_current_mailing_address!
      validate_form_526_current_mailing_address_country!
    end

    def validate_form_526_current_mailing_address_country!
      current_mailing_address = form_attributes.dig('veteran', 'currentMailingAddress')

      return if valid_countries.include?(current_mailing_address['country'])

      raise ::Common::Exceptions::InvalidFieldValue.new('country', current_mailing_address['country'])
    end

    def validate_form_526_change_of_address!
      change_of_address = form_attributes.dig('veteran', 'changeOfAddress')

      validate_form_526_change_of_address_beginning_date!(change_of_address)
      validate_form_526_change_of_address_ending_date!(change_of_address)
      validate_form_526_change_of_address_country!(change_of_address)
    end

    def validate_form_526_change_of_address_beginning_date!(change_of_address)
      return if change_of_address.blank?
      return unless 'TEMPORARY'.casecmp?(change_of_address['addressChangeType'])
      return if Date.parse(change_of_address['beginningDate']) > Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('beginningDate', change_of_address['beginningDate'])
    end

    def validate_form_526_change_of_address_ending_date!(change_of_address)
      return if change_of_address.blank?

      change_type = change_of_address['addressChangeType']
      ending_date = change_of_address['endingDate']

      case change_type&.upcase
      when 'PERMANENT'
        raise ::Common::Exceptions::InvalidFieldValue.new('endingDate', ending_date) if ending_date.present?
      when 'TEMPORARY'
        raise ::Common::Exceptions::InvalidFieldValue.new('endingDate', ending_date) if ending_date.blank?

        beginning_date = change_of_address['beginningDate']
        if Date.parse(beginning_date) >= Date.parse(ending_date)
          raise ::Common::Exceptions::InvalidFieldValue.new('endingDate', ending_date)
        end
      end
    end

    def validate_form_526_change_of_address_country!(change_of_address)
      return if change_of_address.blank?
      return if valid_countries.include?(change_of_address['country'])

      raise ::Common::Exceptions::InvalidFieldValue.new('country', change_of_address['country'])
    end

    def validate_form_526_disabilities!
      validate_form_526_fewer_than_150_disabilities!
      validate_form_526_disability_classification_code!
      validate_form_526_disability_approximate_begin_date!
      validate_form_526_special_issues!
      validate_form_526_disability_unique_names!
    end

    def validate_form_526_fewer_than_150_disabilities!
      disabilities = form_attributes['disabilities']
      return if disabilities.size <= 150

      raise ::Common::Exceptions::InvalidFieldValue.new('disabilities', 'A maximum of 150 disabilities allowed')
    end

    def contention_classification_type_code_list
      @contention_classification_type_code_list ||= if Flipper.enabled?(:claims_api_526_validations_v1_local_bgs)
                                                      service = ClaimsApi::StandardDataService.new(
                                                        external_uid: Settings.bgs.external_uid,
                                                        external_key: Settings.bgs.external_key
                                                      )
                                                      service.get_contention_classification_type_code_list
                                                    else
                                                      bgs_service.data.get_contention_classification_type_code_list
                                                    end
    end

    def bgs_classification_ids
      contention_classification_type_code_list.pluck(:clsfcn_id)
    end

    def validate_form_526_disability_classification_code_end_date!(classification_code, index)
      bgs_disability = contention_classification_type_code_list.find { |d| d[:clsfcn_id] == classification_code }
      end_date = bgs_disability[:end_dt] if bgs_disability

      return if end_date.nil?

      return if Date.parse(end_date) >= Time.zone.today

      raise ::Common::Exceptions::InvalidFieldValue.new("disabilities.#{index}.classificationCode", classification_code)
    end

    def validate_form_526_disability_classification_code!
      form_attributes['disabilities'].each_with_index do |disability, index|
        classification_code = disability['classificationCode']
        next if classification_code.nil? || classification_code.blank?

        if bgs_classification_ids.include?(classification_code)
          validate_form_526_disability_classification_code_end_date!(classification_code, index)
        else
          raise ::Common::Exceptions::InvalidFieldValue.new("disabilities.#{index}.classificationCode",
                                                            classification_code)
        end
      end
    end

    def validate_form_526_disability_approximate_begin_date!
      disabilities = form_attributes['disabilities']

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

        if invalid_type_increase_special_issue?(special_issues:)
          message = "'disability.specialIssues' :: A Special Issue cannot be added to a primary disability after " \
                    'the disability has been rated'
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

    def invalid_type_increase_special_issue?(special_issues:)
      return false unless form_attributes['disabilityActionType'] == 'INCREASE'
      return false if special_issues.blank?

      # if 'specialIssues' includes 'EMP' or 'RRD', then EVSS allows the disability to be submitted with a type of
      # INCREASE otherwise, the disability must not have any special issues
      !(special_issues.include?('EMP') || special_issues.include?('RRD'))
    end

    def validate_form_526_disability_unique_names!
      disabilities = form_attributes['disabilities']
      return if disabilities.blank?

      names = disabilities.map { |d| d['name'].downcase }
      duplicates = names.select { |name| names.count(name) > 1 }.uniq
      masked_duplicates = duplicates.map { |name| mask_all_but_first_character(name) }

      unless duplicates.empty?
        raise ::Common::Exceptions::InvalidFieldValue.new('disabilities.name',
                                                          'Duplicate disability name found: ' \
                                                          "#{masked_duplicates.join(', ')}")
      end
    end

    def mask_all_but_first_character(value)
      return value if value.blank?
      return value unless value.is_a? String

      # Mask all but the first character of the string
      value[0] + ('*' * (value.length - 1))
    end
  end
end
