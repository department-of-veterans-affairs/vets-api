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
      # ensure 'title10ActivationDate' if provided, is after the earliest servicePeriod.activeDutyBeginDate and on or before the current date # rubocop:disable Layout/LineLength
      validate_form_526_title10_activation_date!
      # ensure 'currentMailingAddress' attributes are valid
      validate_form_526_current_mailing_address!
      # ensure 'changeOfAddress.beginningDate' is in the future if 'addressChangeType' is 'TEMPORARY'
      validate_form_526_change_of_address!
      # ensure no more than 150 disabilities are provided
      # ensure any provided 'disability.classificationCode' is a known value in BGS
      validate_form_526_disabilities!
    end

    def retrieve_separation_locations
      ClaimsApi::BRD.new.intake_sites
    rescue
      exception_msg = 'Failed To Obtain Intake Sites (Request Failed)'
      raise ::Common::Exceptions::ServiceUnavailable.new({ source: 'intake_sites', detail: exception_msg })
    end

    def validate_form_526_submission_claim_date!
      return if form_attributes['claimDate'].blank?
      return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

      exception_msg = 'The request failed validation, because the claim date was in the future.'
      raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', exception_msg)
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

        exception_msg = "Provided separation location code is not valid: #{service_period['separationLocationCode']}"
        raise ::Common::Exceptions::InvalidFieldValue.new('Invalid separation location code',
                                                          exception_msg)
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
      # TODO: pull these validations over from original 526 validations
      # validate_form_526_disability_approximate_begin_date!
      # validate_form_526_special_issues!
      # validate_form_526_disability_secondary_disabilities!
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
  end
end
