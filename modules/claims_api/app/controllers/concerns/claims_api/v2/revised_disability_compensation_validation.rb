# frozen_string_literal: true

require 'common/exceptions'
require 'brd/brd'
require 'claims_api/common/exceptions/lighthouse/json_form_validation_error'
require 'claims_api/v2/disability_compensation_shared_service_module'

module ClaimsApi
  module V2
    # rubocop:disable Metrics/ModuleLength
    module RevisedDisabilityCompensationValidation
      include DisabilityCompensationSharedServiceModule
      def validate_form_526_fes_values(_target_veteran = nil)
        return [] if form_attributes.empty?

        @errors = []

        # Validate claim date if provided
        validate_claim_date!

        # Validate service information
        validate_service_information!

        # Validate disabilities
        validate_disabilities!

        # Return collected errors
        @errors

        # TODO: Future PRs will add more validations here
      end

      private

      def validate_claim_date!
        # FES Val Section 2.1: claimDate must be equal to or earlier than today's date
        return if form_attributes['claimDate'].blank?

        claim_date = Date.parse(form_attributes['claimDate'])
        if claim_date > Date.current
          collect_error(
            source: '/claimDate',
            title: 'Bad Request',
            detail: 'The request failed validation, because the claim date was in the future.'
          )
        end
      rescue ArgumentError
        collect_error(
          source: '/claimDate',
          title: 'Bad Request',
          detail: 'Invalid date format for claimDate'
        )
      end

      def validate_service_information!
        # FES Val Section 2.4: serviceInformation validations
        service_info = form_attributes['serviceInformation']
        return if service_info.blank?

        validate_separation_location_codes!(service_info)
        validate_service_periods!(service_info['servicePeriods'])

        # Also validate top-level reserves/federal activation for backward compatibility
        validate_top_level_reserves!(service_info)
      end

      def validate_separation_location_codes!(service_info)
        # FES Val Section 2.4.a: separationLocationCode must match an intake site code in wss-referencedata-services
        service_periods = service_info['servicePeriods']
        return if service_periods.blank?

        any_code_present = service_periods.any? do |service_period|
          service_period['separationLocationCode'].present?
        end

        # only retrieve separation locations if we'll need them
        return unless any_code_present

        separation_locations = retrieve_separation_locations
        return handle_separation_location_error if separation_locations.nil?

        validate_each_separation_code(service_periods, separation_locations)
      end

      def handle_separation_location_error
        collect_error(
          source: '/serviceInformation',
          title: 'Reference Data Service Error',
          detail: 'The Reference Data Service is unavailable to verify the separation location code for the claimant'
        )
      end

      def validate_each_separation_code(service_periods, separation_locations)
        separation_location_ids = separation_locations.pluck(:id).to_set(&:to_s)

        service_periods.each_with_index do |service_period, idx|
          separation_location_code = service_period['separationLocationCode']

          next if separation_location_code.nil? || separation_location_ids.include?(separation_location_code)

          collect_error(
            source: "/serviceInformation/servicePeriods/#{idx}/separationLocationCode",
            title: 'Invalid separation location code',
            detail: "The separation location code (#{idx}) for the claimant is not a valid value."
          )
        end
      end

      def validate_service_periods!(service_periods)
        # FES Val Section 2.4.b: servicePeriods must be provided and between 1-100

        # Skip validation if empty - JSON schema will catch this
        return if service_periods.blank?

        if service_periods.size > 100
          collect_error(
            source: '/serviceInformation/servicePeriods',
            title: 'Invalid array',
            detail: "Number of service periods #{service_periods.size} must be between 1 and 100 inclusive"
          )
        end

        service_periods.each_with_index do |period, index|
          validate_single_service_period!(period, index)
        end
      end

      def validate_single_service_period!(period, index)
        # TODO: Need to revisit as per ongoing conversation with Firefly
        # FES Val Section 2.4.b.ii-iv: validate dates chronology, 180-day limit, reserves/guard
        begin_date = parse_date_safely(period['activeDutyBeginDate'])
        end_date = parse_date_safely(period['activeDutyEndDate'])

        validate_service_period_dates!(period, index, begin_date, end_date)

        # Skip service branch validation - it requires external service calls
        # This will be validated downstream in the submission process

        # Validate reserves/national guard specific fields
        validate_reserves_national_guard!(period, index) if period['reservesNationalGuardService'].present?
      end

      def validate_service_period_dates!(period, index, begin_date, end_date)
        validate_dates_chronology!(period, index, begin_date, end_date)
        validate_future_date_limit!(index, end_date)
      end

      def validate_dates_chronology!(_period, index, begin_date, end_date)
        return unless begin_date && end_date && end_date < begin_date

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/activeDutyEndDate",
          title: 'Invalid service period duty dates',
          detail: "activeDutyEndDate (#{index}) needs to be after activeDutyBeginDate."
        )
      end

      def validate_future_date_limit!(index, end_date)
        return unless end_date && end_date > Date.current + 180.days

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/activeDutyEndDate",
          title: 'Invalid end service period duty date',
          detail: 'The active duty end date for this service period is more than 180 days in the future'
        )
      end

      def validate_reserves_national_guard!(period, index)
        # FES Val Section 2.4.c: reservesNationalGuardService validation rules
        rng_service = period['reservesNationalGuardService']

        # Validate obligation dates
        if rng_service['obligationTermOfServiceFromDate'].blank?
          collect_error(
            source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService",
            title: 'Missing required field',
            detail: 'The service period is missing a required start date for the obligation terms of service'
          )
        end

        if rng_service['obligationTermOfServiceToDate'].blank?
          collect_error(
            source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService",
            title: 'Missing required field',
            detail: 'The service period is missing a required end date for the obligation terms of service'
          )
        end

        # Validate title 10 activation
        if rng_service['title10Activation'].present?
          validate_title10_activation!(rng_service['title10Activation'], period, index)
        end
      end

      def validate_title10_activation!(activation, period, index)
        # FES Val Section 2.4.c.iii-iv: title10Activation requires dates and validation
        validate_anticipated_separation_date!(activation, index)

        activation_date = parse_date_safely(activation['title10ActivationDate'])
        begin_date = parse_date_safely(period['activeDutyBeginDate'])

        validate_activation_date_chronology!(activation, period, index, activation_date, begin_date)
        validate_activation_date_not_future!(activation, index, activation_date)
      end

      def validate_anticipated_separation_date!(activation, index)
        return if activation['anticipatedSeparationDate'].present?

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService/title10Activation",
          title: 'Missing required field',
          detail: 'Title 10 activation is missing the anticipated separation date'
        )
      end

      def validate_activation_date_chronology!(activation, period, index, activation_date, begin_date)
        return unless activation_date && begin_date && activation_date < begin_date

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService/title10Activation",
          title: 'Invalid value',
          detail: 'Reserves national guard title 10 activation date ' \
                  "(#{activation['title10ActivationDate']}) is before the earliest active duty begin date " \
                  "(#{period['activeDutyBeginDate']})"
        )
      end

      def validate_activation_date_not_future!(activation, index, activation_date)
        return unless activation_date && activation_date > Date.current

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService/title10Activation",
          title: 'Invalid value',
          detail: 'Reserves national guard title 10 activation date is in the future: ' \
                  "#{activation['title10ActivationDate']}"
        )
      end

      def validate_top_level_reserves!(service_info)
        # Handle backward compatibility with reserves at top level of serviceInformation
        # Note: Top-level reserves/federal activation is legacy structure
        # We only validate federal activation here, not reserves obligation dates
        validate_top_level_federal_activation!(service_info['federalActivation'])
      end

      def validate_top_level_federal_activation!(federal_activation)
        return if federal_activation.blank?

        if federal_activation['anticipatedSeparationDate'].blank?
          collect_error(
            source: '/serviceInformation/federalActivation',
            title: 'Missing required field',
            detail: 'anticipatedSeparationDate is missing or blank'
          )
        end

        # Validate activation date if present
        activation_date = parse_date_safely(federal_activation['activationDate'])
        if activation_date && activation_date > Date.current
          collect_error(
            source: '/serviceInformation/federalActivation',
            title: 'Invalid value',
            detail: "Federal activation date is in the future: #{federal_activation['activationDate']}"
          )
        end
      end

      def validate_disabilities!
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?

        validate_disability_name
        validate_form_526_disability_classification_code
        validate_form_526_disability_approximate_begin_date
        validate_form_526_disability_service_relevance
        validate_special_issues
        validate_form_526_disability_secondary_disabilities
      end

      # From V2 disability_compensation_validation.rb:270-278
      # FES Val Section 7.a: Must have at least 1 disability
      # FES Val Section 7.m: name must match regex pattern for a disability with disabilityActionType=NEW
      # Validates that disability name is present for each disability
      def validate_disability_name
        form_attributes['disabilities'].each_with_index do |disability, idx|
          disability_name = disability&.dig('name')
          if disability_name.blank?
            collect_error(
              source: "/disabilities/#{idx}/name",
              title: 'Missing required field',
              detail: "The disability name at index #{idx} is required"
            )
          end
        end
      end

      # From V2 disability_compensation_validation.rb:280-295
      # FES Val Section 7.k: classificationCode (if present) must match a value in the BGS referencedata list
      # Validates disability classification codes exist in BRD and are active
      def validate_form_526_disability_classification_code
        return if (form_attributes['disabilities'].pluck('classificationCode') - [nil]).blank?

        form_attributes['disabilities'].each_with_index do |disability, idx|
          next if disability['classificationCode'].blank?

          if brd_classification_ids.include?(disability['classificationCode'].to_i)
            validate_form_526_disability_code_enddate(disability['classificationCode'].to_i, idx)
          else
            collect_error(
              source: "/disabilities/#{idx}/classificationCode",
              title: 'Invalid classification code',
              detail: "The classification code for disability #{idx} is not valid"
            )
          end
        end
      end

      # From V2 disability_compensation_validation.rb:297-311
      # FES Val Section 7.k: The classification code must be active (not expired)
      # Validates that classification codes have not expired (endDateTime check)
      def validate_form_526_disability_code_enddate(classification_code, idx, sd_idx = nil)
        reference_disability = brd_disabilities.find { |x| x[:id] == classification_code }
        end_date_time = reference_disability[:endDateTime] if reference_disability
        return if end_date_time.nil?

        if Date.parse(end_date_time) < Time.zone.today
          source_message = if sd_idx
                             "/disabilities/#{idx}/secondaryDisability/#{sd_idx}/classificationCode"
                           else
                             "/disabilities/#{idx}/classificationCode"
                           end
          collect_error(
            source: source_message,
            title: 'Invalid classification code',
            detail: 'The classification code is no longer active'
          )
        end
      end

      # From V2 disability_compensation_validation.rb:313-328
      # FES Val Section 7.t: approximateBeginDate (if present) must be in the past
      # Validates disability approximate dates are valid and in the past
      def validate_form_526_disability_approximate_begin_date
        disabilities = form_attributes&.dig('disabilities')
        return if disabilities.blank?

        disabilities.each_with_index do |disability, idx|
          approx_begin_date = disability&.dig('approximateDate')
          next if approx_begin_date.blank?

          unless date_is_valid?(approx_begin_date, "disability/#{idx}/approximateDate")
            collect_error(
              source: "/disabilities/#{idx}/approximateDate",
              title: 'Invalid date',
              detail: "Invalid date format for disability #{idx} approximateDate"
            )
            next
          end

          next if date_is_valid_against_current_time_after_check_on_format?(approx_begin_date)

          collect_error(
            source: "/disabilities/#{idx}/approximateDate",
            title: 'Invalid date',
            detail: "Approximate begin date for disability #{idx} cannot be in the future"
          )
        end
      end

      # From V2 disability_compensation_validation.rb:330-343
      # FES Val Section 7: serviceRelevance is required if disabilityActionType is NEW
      # Validates service relevance is present when disabilityActionType is NEW
      def validate_form_526_disability_service_relevance
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?

        disabilities.each_with_index do |disability, idx|
          disability_action_type = disability&.dig('disabilityActionType')
          service_relevance = disability&.dig('serviceRelevance')
          if disability_action_type == 'NEW' && service_relevance.blank?
            collect_error(
              source: "/disabilities/#{idx}/serviceRelevance",
              title: 'Missing required field',
              detail: "Service relevance is required for disability #{idx} when action type is NEW"
            )
          end
        end
      end

      # From V2 disability_compensation_validation.rb:345-363
      # FES Val Section 7.w: specialIssues cannot be POW unless JSON has valid confinements
      # FES Val Section 7.u: specialIssues must be null if disabilityActionType=INCREASE (except EMP/RRD)
      # Validates special issues - specifically POW requires confinements
      def validate_special_issues
        form_attributes['disabilities'].each_with_index do |disability, idx|
          next if disability['specialIssues'].blank?

          confinements = form_attributes['serviceInformation']&.dig('confinements')
          disability_action_type = disability&.dig('disabilityActionType')
          if disability['specialIssues'].include? 'POW'
            if confinements.blank?
              collect_error(
                source: "/disabilities/#{idx}/specialIssues",
                title: 'Missing required field',
                detail: 'Confinements are required when special issue POW is selected'
              )
            elsif disability_action_type == 'INCREASE'
              collect_error(
                source: "/disabilities/#{idx}/disabilityActionType",
                title: 'Invalid action type',
                detail: 'Disability action type cannot be INCREASE when special issue POW is selected'
              )
            end
          end
        end
      end

      # From V2 disability_compensation_validation.rb:365-390
      # FES Val Section 7.y.iii: secondaryDisabilities required if primary has disabilityActionType=NONE
      # Validates secondary disabilities - required when action type is NONE,
      # validates classification codes, and approximate dates
      def validate_form_526_disability_secondary_disabilities # rubocop:disable Metrics/MethodLength
        form_attributes['disabilities'].each_with_index do |disability, dis_idx|
          if disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].blank?
            collect_error(
              source: "/disabilities/#{dis_idx}/secondaryDisabilities",
              title: 'Missing required field',
              detail: 'Secondary disabilities are required when disability action type is NONE'
            )
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

      # From V2 disability_compensation_validation.rb:392-411
      # FES Val Section 7.y.ii: name must match regex pattern for SECONDARY disability
      # FES Val Section 7.y.v: disabilityActionType must be SECONDARY
      # Validates required fields for secondary disabilities
      def validate_form_526_disability_secondary_disability_required_fields(disability, disability_idx)
        disability['secondaryDisabilities'].each_with_index do |secondary_disability, sd_idx|
          sd_name = secondary_disability&.dig('name')
          sd_classification_code = secondary_disability&.dig('classificationCode')

          # Check if secondary disability has neither name nor classification code
          if sd_name.blank? && sd_classification_code.blank?
            collect_error(
              source: "/disabilities/#{disability_idx}/secondaryDisabilities/#{sd_idx}/name",
              title: 'Missing required field',
              detail: 'Secondary disability must have either name or classification code'
            )
          elsif sd_name.present? && sd_name !~ %r{^[a-zA-Z0-9\-'.,&()/ ]+$}
            # Validate name format if present
            collect_error(
              source: "/disabilities/#{disability_idx}/secondaryDisabilities/#{sd_idx}/name",
              title: 'Invalid format',
              detail: 'Secondary disability name has invalid format or exceeds 255 characters'
            )
          end
        end
      end

      # From V2 disability_compensation_validation.rb:413-419
      # FES Val Section 7.y.i: classificationCode (if present) must be valid if disabilityActionType=SECONDARY
      # Validates secondary disability classification codes exist in BRD
      def validate_form_526_disability_secondary_disability_classification_code(secondary_disability, dis_idx, sd_idx)
        return if brd_classification_ids.include?(secondary_disability['classificationCode'].to_i)

        collect_error(
          source: "/disabilities/#{dis_idx}/secondaryDisabilities/#{sd_idx}/classificationCode",
          title: 'Invalid classification code',
          detail: 'Secondary disability classification code is not valid'
        )
      end

      # From V2 disability_compensation_validation.rb:421-430
      # FES Val Section 7.y.vii: approximateBeginDate must be in the past for secondary disabilities
      # Validates secondary disability approximate dates are valid and in the past
      def validate_form_526_disability_secondary_disability_approximate_begin_date(secondary_disability, dis_idx,
                                                                                   sd_idx)
        return unless date_is_valid?(secondary_disability['approximateDate'],
                                     'disabilities.secondaryDisabilities.approximateDate')

        return if date_is_valid_against_current_time_after_check_on_format?(secondary_disability['approximateDate'])

        collect_error(
          source: "/disabilities/#{dis_idx}/secondaryDisabilities/#{sd_idx}/approximateDate",
          title: 'Invalid date',
          detail: 'Secondary disability approximate date cannot be in the future'
        )
      end

      # From V2 disability_compensation_validation.rb - helper method
      # Checks if date string can be parsed as a valid date
      def date_is_valid?(date_string, _field_name)
        Date.parse(date_string)
        true
      rescue ArgumentError
        false
      end

      # From V2 disability_compensation_validation.rb - helper method
      # Checks if date is not in the future (must be <= current date)
      def date_is_valid_against_current_time_after_check_on_format?(date_string)
        Date.parse(date_string) <= Date.current
      rescue ArgumentError
        false
      end

      def parse_date_safely(date_string)
        Date.parse(date_string)
      rescue
        nil
      end

      def collect_error(source:, title:, detail:)
        @errors << {
          source:,
          title:,
          detail:,
          status: '422'
        }
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
