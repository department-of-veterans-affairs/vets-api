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

        # Validate veteran information
        validate_veteran!

        # Return collected errors
        error_collection if @errors

        # TODO: Future PRs will add more validations here
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

      ### FES Val Section 5: veteran validations
      def validate_veteran!
        # FES Val Section 5.b: currentMailingAddress validations
        validate_current_mailing_address!

        # FES Val Section 5.c: changeOfAddress validations
        validate_change_of_address!
      end

      # From V2 disability_compensation_validation.rb:224-250
      # FES Val Section 5.b: currentMailingAddress validations
      def validate_current_mailing_address!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if mailing_address.blank?

        # FES Val Section 5.b.ii: city, state and zipCode are required if type=DOMESTIC
        validate_domestic_address_fields!(mailing_address, 'mailingAddress') if mailing_address['type'] == 'DOMESTIC'

        # FES Val Section 5.b.iii: city and country are required if type=INTERNATIONAL
        if mailing_address['type'] == 'INTERNATIONAL'
          validate_international_address_fields!(mailing_address, 'mailingAddress')
        end

        # FES Val Section 5.b.iv: MilitaryStateCode, militaryPostOfficeTypeCode and zipFirstFive if type=MILITARY
        validate_military_address_fields!(mailing_address, 'mailingAddress') if mailing_address['type'] == 'MILITARY'

        # FES Val Section 5.b.vi: country must be in the list provided by the referenceDataService
        validate_address_country!(mailing_address, 'mailingAddress')
      end

      # From V2 disability_compensation_validation.rb:55-196
      # FES Val Section 5.c: changeOfAddress validations
      def validate_change_of_address!
        change_of_address = form_attributes['changeOfAddress']
        return if change_of_address.blank?

        validate_change_of_address_dates!(change_of_address)
        validate_change_of_address_fields!(change_of_address)
      end

      def validate_change_of_address_dates!(change_of_address)
        if change_of_address['addressChangeType'] == 'TEMPORARY'
          validate_temporary_address_dates!(change_of_address)
        elsif change_of_address['addressChangeType'] == 'PERMANENT'
          validate_permanent_address_dates!(change_of_address)
        end
      end

      def validate_temporary_address_dates!(change_of_address)
        validate_temporary_required_dates!(change_of_address)
        validate_temporary_date_logic!(change_of_address)
      end

      def validate_temporary_required_dates!(change_of_address)
        # FES Val Section 5.c.i.2: Missing beginningDate
        if change_of_address['beginningDate'].blank?
          collect_error(
            source: '/changeOfAddress/beginningDate',
            title: 'Missing required field',
            detail: 'beginningDate is required for temporary address'
          )
        end

        # FES Val Section 5.c.i.3: Missing endingDate
        if change_of_address['endingDate'].blank?
          collect_error(
            source: '/changeOfAddress/endingDate',
            title: 'Missing required field',
            detail: 'endingDate is required for temporary address'
          )
        end
      end

      def validate_temporary_date_logic!(change_of_address)
        # FES Val Section 5.c.iii.2: beginningDate must be in the future if addressChangeType is TEMPORARY
        if change_of_address['beginningDate'].present?
          begin_date = parse_date_safely(change_of_address['beginningDate'])
          if begin_date && begin_date <= Date.current
            collect_error(
              source: '/changeOfAddress/beginningDate',
              title: 'Invalid beginningDate',
              detail: 'BeginningDate cannot be in the past: YYYY-MM-DD'
            )
          end
        end

        # FES Val Section 5.c.iv.2: beginningDate and endingDate must be in chronological order
        validate_temporary_date_order!(change_of_address)
      end

      def validate_temporary_date_order!(change_of_address)
        return unless change_of_address['beginningDate'].present? && change_of_address['endingDate'].present?

        begin_date = parse_date_safely(change_of_address['beginningDate'])
        end_date = parse_date_safely(change_of_address['endingDate'])
        return unless begin_date && end_date && begin_date >= end_date

        # FES Val Section 5.c.iv.2: Invalid beginningDate
        collect_error(
          source: '/changeOfAddress/beginningDate',
          title: 'Invalid beginningDate',
          detail: 'BeginningDate cannot be after endingDate: YYYY-MM-DD'
        )
      end

      def validate_permanent_address_dates!(change_of_address)
        # FES Val Section 5.c.ii.2: Cannot provide endingDate
        return if change_of_address['endingDate'].blank?

        collect_error(
          source: '/changeOfAddress/endingDate',
          title: 'Cannot provide endingDate',
          detail: 'EndingDate cannot be provided for a permanent address.'
        )
      end

      def validate_change_of_address_fields!(change_of_address)
        # FES Val Section 5.c.v-viii: Address field validations based on type
        case change_of_address['type']
        when 'DOMESTIC'
          validate_domestic_address_fields!(change_of_address, 'changeOfAddress')
        when 'INTERNATIONAL'
          validate_international_address_fields!(change_of_address, 'changeOfAddress')
        when 'MILITARY'
          validate_military_address_fields!(change_of_address, 'changeOfAddress')
        end

        # FES Val Section 5.c.x: country must be in the list provided by the referenceDataService
        validate_address_country!(change_of_address, 'changeOfAddress')
      end

      # Helper methods for address validation
      def validate_domestic_address_fields!(address, address_type)
        # FES Val Section 5.b.ii.2 / 5.c.v.2: Missing city
        validate_required_field!(address, address_type, 'city', 'City is required for domestic address')
        # FES Val Section 5.b.ii.3 / 5.c.v.3: Missing state
        validate_required_field!(address, address_type, 'state', 'State is required for domestic address')
        # FES Val Section 5.b.ii.4 / 5.c.v.4: Missing zipFirstFive
        validate_required_field!(address, address_type, 'zipFirstFive',
                                 'ZipFirstFive is required for domestic address')
      end

      def validate_required_field!(address, address_type, field, detail)
        return if address[field].present?

        # Determine the correct path based on address_type
        source_path = if address_type == 'mailingAddress'
                        "/veteranIdentification/#{address_type}/#{field}"
                      else
                        "/#{address_type}/#{field}"
                      end

        collect_error(
          source: source_path,
          title: 'Missing required field',
          detail:
        )
      end

      def validate_international_address_fields!(address, address_type)
        # FES Val Section 5.b.iii.2 / 5.c.vi.2: Missing city
        validate_required_field!(address, address_type, 'city', 'City is required for international address')
        # FES Val Section 5.b.iii.3 / 5.c.vi.3: Missing country
        validate_required_field!(address, address_type, 'country', 'Country is required for international address')
        # FES Val Section 5.b.v.2 / 5.c.viii.2: Missing internationalPostalCode
        validate_required_field!(address, address_type, 'internationalPostalCode',
                                 'InternationalPostalCode is required for international address')
      end

      def validate_military_address_fields!(address, address_type)
        # FES Val Section 5.b.iv.2 / 5.c.vii.2: Missing militaryPostOfficeTypeCode
        validate_required_field!(address, address_type, 'militaryPostOfficeTypeCode',
                                 'MilitaryPostOfficeTypeCode is required for military address')
        # FES Val Section 5.b.iv.3 / 5.c.vii.3: Missing militaryStateCode
        validate_required_field!(address, address_type, 'militaryStateCode',
                                 'MilitaryStateCode is required for military address')
        # NOTE: zipFirstFive is also required for MILITARY addresses
        validate_required_field!(address, address_type, 'zipFirstFive',
                                 'ZipFirstFive is required for military address')
      end

      def validate_address_country!(address, address_type)
        return if address['country'].blank?

        # FES Val Section 5.b.vii.2 / 5.c.x.2: Handle BGS service unavailable
        countries = valid_countries
        if countries.nil?
          # Determine the correct path based on address_type
          source_path = if address_type == 'mailingAddress'
                          "/veteranIdentification/#{address_type}/country"
                        else
                          "/#{address_type}/country"
                        end

          collect_error(
            source: source_path,
            title: 'Internal Server Error',
            detail: 'Failed To Obtain Country Types (Request Failed)'
          )
          return
        end

        # FES Val Section 5.b.vi.2 / 5.c.ix.2: Invalid country
        return if countries.include?(address['country'])

        # Determine the correct path based on address_type
        source_path = if address_type == 'mailingAddress'
                        "/veteranIdentification/#{address_type}/country"
                      else
                        "/#{address_type}/country"
                      end

        collect_error(
          source: source_path,
          title: 'Invalid country',
          detail: "Provided country is not valid: #{address['country']}"
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
