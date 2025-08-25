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

        # Validate claim date if provided
        validate_claim_date!

        # Validate service information
        validate_service_information!

        # Validate disabilities
        validate_disabilities!

        # Validate special circumstances
        validate_special_circumstances!

        # Return collected errors
        error_collection if @errors
      end

      private

      def validate_claim_date!
        # PDF Section 2.1: claimDate must be equal to or earlier than today's date
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
        # PDF Section 2.4: serviceInformation validations
        service_info = form_attributes['serviceInformation']
        return if service_info.blank?

        validate_separation_location_codes!(service_info)
        validate_service_periods!(service_info['servicePeriods'])

        # Also validate top-level reserves/federal activation for backward compatibility
        validate_top_level_reserves!(service_info)
      end

      def validate_separation_location_codes!(service_info)
        # PDF Section 2.4.a: separationLocationCode must match an intake site code in wss-referencedata-services
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
        # PDF Section 2.4.b: servicePeriods must be provided and between 1-100

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
        # PDF Section 2.4.b.ii-iv: validate dates chronology, 180-day limit, reserves/guard
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
        # PDF Section 2.4.c: reservesNationalGuardService validation rules
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
        # PDF Section 2.4.c.iii-iv: title10Activation requires dates and validation
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

      ### FES Val Section 7: disabilities validations
      def validate_disabilities!
        disabilities = form_attributes['disabilities']
        return if disabilities.nil?

        # FES Val Section 7.a-b: Must have 1-150 disabilities
        validate_disabilities_count!(disabilities)

        # FES Val Warning Section ii: Check for duplicate disability names
        # Note: This is listed as a warning but actually causes FES errors
        validate_duplicate_disability_names!(disabilities)

        disabilities.each_with_index do |disability, idx|
          validate_disability_fields!(disability, idx)
          validate_disability_dates!(disability, idx)
          validate_disability_special_issues!(disability, idx)
        end
      end

      def validate_disabilities_count!(disabilities)
        # FES Val Section 7.a: Must have at least 1 disability
        if disabilities.empty?
          collect_error(
            source: '/disabilities',
            title: 'Missing required field',
            detail: 'List of disabilities must be provided'
          )
        end

        # FES Val Section 7.b: Maximum of 150 disabilities
        return unless disabilities.size > 150

        collect_error(
          source: '/disabilities',
          title: 'Invalid array',
          detail: "Number of disabilities #{disabilities.size} must be between 1 and 150 inclusive"
        )
      end

      def validate_disability_fields!(disability, idx)
        action_type = disability['disabilityActionType']

        # Section 7.f.ii: diagnosticCode required for NONE with secondary disabilities
        validate_none_with_secondary!(disability, idx, action_type)

        # Section 7.m.ii, 7.n.ii: name validations
        validate_disability_name!(disability, idx)

        # Section 7.o.ii: REOPEN not supported
        validate_reopen_not_supported!(disability, idx, action_type)
      end

      def validate_none_with_secondary!(disability, idx, action_type)
        return unless action_type == 'NONE' && disability['secondaryDisabilities'].present?
        return if disability['diagnosticCode'].present?

        collect_error(
          source: "/disabilities/#{idx}/diagnosticCode",
          title: 'Bad Request',
          detail: 'The request failed disability validation: The disability Action Type of "NONE" ' \
                  'is not currently supported.'
        )
      end

      def validate_reopen_not_supported!(_disability, idx, action_type)
        return unless action_type == 'REOPEN'

        collect_error(
          source: "/disabilities/#{idx}/disabilityActionType",
          title: 'Bad Request',
          detail: 'The request failed disability validation: The disability Action Type of "REOPEN" ' \
                  'is not currently supported. REOPEN will be supported in a future release'
        )
      end

      def validate_disability_name!(disability, idx)
        name = disability['name']
        action_type = disability['disabilityActionType']

        return validate_name_required!(idx) if name.blank?

        validate_name_length!(name, idx)
        validate_new_disability_name_format!(name, action_type, idx)
      end

      def validate_name_required!(idx)
        collect_error(
          source: "/disabilities/#{idx}/name",
          title: 'Missing required field',
          detail: "The disability name (#{idx}) is required"
        )
      end

      def validate_name_length!(name, idx)
        return unless name.length > 255

        collect_error(
          source: "/disabilities/#{idx}/name",
          title: 'Invalid value',
          detail: 'The disability name must be less than 256 characters'
        )
      end

      def validate_new_disability_name_format!(name, action_type, idx)
        return unless action_type == 'NEW' && !name.match?(%r{^[a-zA-Z0-9\-'.,/\(\)]([a-zA-Z0-9\-',. ])*$})

        collect_error(
          source: "/disabilities/#{idx}/name",
          title: 'Bad Request',
          detail: "The disability name \"#{name}\" does not match the expected format for a " \
                  'disabilityActionType of "NEW"'
        )
      end

      def validate_disability_dates!(disability, idx)
        approximate_date = disability['approximateBeginDate']
        return if approximate_date.blank?

        # Section 7.q.ii, 7.r.ii, 7.s.ii: Date format validations
        validate_date_format!(approximate_date, idx)

        # Parse and validate date
        parsed_date = parse_date_safely(approximate_date)
        return if parsed_date.nil?

        # Section 7.t.ii: approximateBeginDate must be in the past
        return unless parsed_date > Date.current

        collect_error(
          source: "/disabilities/#{idx}/approximateBeginDate",
          title: 'Invalid value',
          detail: 'The ApproximateBeginDate in primary disability must be in the past'
        )
      end

      def validate_date_format!(date_string, idx)
        parts = date_string.split('-')
        validate_month_format!(parts, idx)
        validate_day_format!(parts, idx)
        validate_day_year_combination!(date_string, parts, idx)
      end

      def validate_month_format!(parts, idx)
        # Section 7.q.ii: Month validation (must be 1-12)
        return unless parts.length >= 2

        month = parts[1].to_i
        return unless month < 1 || month > 12

        collect_error(
          source: "/disabilities/#{idx}/approximateBeginDate",
          title: 'Invalid value',
          detail: 'The month is not a valid value'
        )
      end

      def validate_day_format!(parts, idx)
        # Section 7.r.ii: Day validation
        return unless parts.length == 3

        day = parts[2].to_i
        month = parts[1].to_i
        return unless day < 1 || day > 31 || (month == 2 && day > 29)

        collect_error(
          source: "/disabilities/#{idx}/approximateBeginDate",
          title: 'Invalid value',
          detail: 'The day is not a valid value'
        )
      end

      def validate_day_year_combination!(date_string, parts, idx)
        # Section 7.s.ii: Day and Year without month not allowed
        return unless date_string.match?(/^\d{4}-\d{2}$/) && parts[1] == '00'

        collect_error(
          source: "/disabilities/#{idx}/approximateBeginDate",
          title: 'Invalid value',
          detail: 'Day and Year is not a valid combination. Accepted combinations are: ' \
                  'Year/Month/Day, Year/Month, Or Year'
        )
      end

      def validate_disability_special_issues!(disability, idx)
        special_issues = disability['specialIssues']
        return if special_issues.blank?

        validate_increase_special_issues!(disability, idx, special_issues)
        validate_hepc_special_issue!(disability, idx, special_issues)
        validate_pow_special_issue!(idx, special_issues)
      end

      def validate_increase_special_issues!(disability, idx, special_issues)
        action_type = disability['disabilityActionType']
        # Section 7.u.ii: specialIssues validation for INCREASE
        return unless action_type == 'INCREASE' && special_issues.present?
        return if [['EMP'], ['RRD']].include?(special_issues)

        collect_error(
          source: "/disabilities/#{idx}/specialIssues",
          title: 'Invalid value',
          detail: 'A Special Issue cannot be added to a primary disability after the disability has been rated'
        )
      end

      def validate_hepc_special_issue!(disability, idx, special_issues)
        name = disability['name']
        # Section 7.v.ii: HEPC special issue validation
        return unless special_issues.include?('HEPC') && name != 'Hepatitis'

        collect_error(
          source: "/disabilities/#{idx}/specialIssues",
          title: 'Invalid value',
          detail: 'A special issue of HEPC can only exist for the disability Hepatitis'
        )
      end

      def validate_pow_special_issue!(idx, special_issues)
        # Section 7.w.ii: POW requires confinements
        return unless special_issues.include?('POW')

        confinements = form_attributes.dig('serviceInformation', 'confinements')
        return if confinements.present?

        collect_error(
          source: "/disabilities/#{idx}/specialIssues",
          title: 'Invalid value',
          detail: 'A prisoner of war must have at least one period of confinement record'
        )
      end

      def validate_duplicate_disability_names!(disabilities)
        # FES Val Section 7.x: The same name must appear only once in the list of disabilities
        # Although listed as a warning, this actually causes FES errors
        names = disabilities.map { |d| d['name'] }.compact
        duplicates = names.select { |name| names.count(name) > 1 }.uniq

        return if duplicates.empty?

        duplicates.each do |duplicate_name|
          collect_error(
            source: '/disabilities',
            title: 'Invalid value',
            detail: "Duplicate disability name found: #{duplicate_name}"
          )
        end
      end

      ### FES Val Section 10: Special Circumstances validation
      def validate_special_circumstances!
        special_circumstances = form_attributes['specialCircumstances']
        return if special_circumstances.nil?

        # Section 10.a is crossed out: "specialCircumstances must not be in the JSON request"
        # Section 10.b: A maximum of 100 special circumstances are allowed
        return unless special_circumstances.is_a?(Array) && special_circumstances.size > 100

        collect_error(
          source: '/specialCircumstances',
          title: 'Invalid array',
          detail: 'A maximum of 100 special circumstances are allowed'
        )
      end

      # Utility methods grouped at the bottom
      def parse_date_safely(date_string)
        Date.parse(date_string)
      rescue
        nil
      end

      def errors_array
        @errors ||= []
      end

      def collect_error(source:, title:, detail:)
        errors_array.push(
          {
            source:,
            title:,
            detail:,
            status: '422'
          }
        )
      end

      def error_collection
        errors_array.uniq! { |e| e[:detail] }
        errors_array
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
