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

        # Validate disability action type and name format
        validate_disability_action_type_and_name!

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
            detail: 'The service period is missing a required start date for the obligation terms of service'
          )
        end

        if rng_service['obligationTermOfServiceToDate'].blank?
          collect_error(
            source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService",
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
          detail: 'Title 10 activation is missing the anticipated separation date'
        )
      end

      def validate_activation_date_chronology!(activation, period, index, activation_date, begin_date)
        return unless activation_date && begin_date && activation_date < begin_date

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService/title10Activation",
          detail: 'Reserves national guard title 10 activation date ' \
                  "(#{activation['title10ActivationDate']}) is before the earliest active duty begin date " \
                  "(#{period['activeDutyBeginDate']})"
        )
      end

      def validate_activation_date_not_future!(activation, index, activation_date)
        return unless activation_date && activation_date > Date.current

        collect_error(
          source: "/serviceInformation/servicePeriods/#{index}/reservesNationalGuardService/title10Activation",
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
            detail: 'anticipatedSeparationDate is missing or blank'
          )
        end

        # Validate activation date if present
        activation_date = parse_date_safely(federal_activation['activationDate'])
        if activation_date && activation_date > Date.current
          collect_error(
            source: '/serviceInformation/federalActivation',
            detail: "Federal activation date is in the future: #{federal_activation['activationDate']}"
          )
        end
      end

      ### FES Val Section 5: veteran validations
      def validate_veteran!
        # FES Val Section 5.b: mailingAddress validations
        validate_current_mailing_address!
        # FES Val Section 5.c: changeOfAddress validations
        validate_change_of_address!
      end

      # FES Val Section 5.c: changeOfAddress validations
      def validate_change_of_address!
        change_of_address = form_attributes['changeOfAddress']
        return if change_of_address.blank?

        # FES Val Section 5.c.i-ii: Validate date requirements
        validate_change_of_address_dates!(change_of_address)
        # FES Val Section 5.c.iii-iv: Validate date logic
        validate_change_of_address_date_logic!(change_of_address)
        # FES Val Section 5.c.v-x: Validate address fields based on type
        validate_change_of_address_fields!(change_of_address)
      end

      # FES Val Section 5.c.iii-iv: Date validation logic
      def validate_change_of_address_date_logic!(change_of_address)
        return if change_of_address['typeOfAddressChange'] != 'TEMPORARY'

        begin_date = parse_date_safely(change_of_address.dig('dates', 'beginDate'))
        end_date = parse_date_safely(change_of_address.dig('dates', 'endDate'))

        # FES Val Section 5.c.iii: beginningDate must be in the future if TEMPORARY
        validate_temporary_begin_date_future!(begin_date)

        # FES Val Section 5.c.iv: beginningDate and endingDate must be in chronological order
        validate_dates_chronological_order!(begin_date, end_date)
      end

      def validate_temporary_begin_date_future!(begin_date)
        return if begin_date.blank? || begin_date > Date.current

        collect_error(
          source: '/changeOfAddress/dates/beginDate',
          title: 'Invalid beginningDate',
          detail: "BeginningDate cannot be in the past: #{begin_date}"
        )
      end

      def validate_dates_chronological_order!(begin_date, end_date)
        return if begin_date.blank? || end_date.blank? || begin_date <= end_date

        collect_error(
          source: '/changeOfAddress/dates/beginDate',
          title: 'Invalid beginningDate',
          detail: "BeginningDate cannot be after endingDate: #{begin_date}"
        )
      end

      # FES Val Section 5.b: mailingAddress validations
      def validate_current_mailing_address!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if mailing_address.blank?

        # FES Val Section 5.b.ii-iv: Address field validations
        # Determine address type based on country field or presence of international fields
        if mailing_address['country'] == 'USA'
          validate_usa_mailing_address!(mailing_address)
        elsif mailing_address['country'] != 'USA' || mailing_address['internationalPostalCode'].present?
          # FES Val Section 5.b.iii: Address field validations for INTERNATIONAL
          # Treat as international if country is non-USA or has internationalPostalCode
          validate_international_mailing_address!(mailing_address)
        end

        # FES Val Section 5.b.vi: Validate country against reference data
        validate_address_country!(mailing_address, 'mailingAddress')

        # FES Val Section 5.b.v: Validate internationalPostalCode for non-USA countries
        validate_international_postal_code!(mailing_address)
      end

      def validate_international_mailing_address!(mailing_address)
        # FES Val Section 5.b.iii.2: City required for INTERNATIONAL addresses
        if mailing_address['city'].blank?
          collect_error(
            source: '/veteranIdentification/mailingAddress/city',
            detail: 'City is required'
          )
        end

        # FES Val Section 5.b.iii.3: Country required for INTERNATIONAL addresses
        if mailing_address['country'].blank?
          collect_error(
            source: '/veteranIdentification/mailingAddress/country',
            detail: 'The country provided is not valid.'
          )
        end
      end

      def validate_usa_mailing_address!(mailing_address)
        # FES Val Section 5.b.ii.3: State required for USA addresses
        if mailing_address['state'].blank?
          collect_error(
            source: '/veteranIdentification/mailingAddress/state',
            detail: 'State is required for USA addresses'
          )
        end

        # FES Val Section 5.b.ii.4: ZipFirstFive required for USA addresses
        if mailing_address['zipFirstFive'].blank?
          collect_error(
            source: '/veteranIdentification/mailingAddress/zipFirstFive',
            detail: 'ZipFirstFive is required for USA addresses'
          )
        end

        # Validate internationalPostalCode should NOT be present for USA
        return if mailing_address['internationalPostalCode'].blank?

        collect_error(
          source: '/veteranIdentification/mailingAddress/internationalPostalCode',
          detail: 'InternationalPostalCode should not be provided for USA addresses'
        )
      end

      def validate_address_country!(address, address_type)
        return if address['country'].blank?

        countries = valid_countries
        source_prefix = address_type == 'changeOfAddress' ? '' : '/veteranIdentification'
        if countries.nil?
          # FES Val Section 5.b.vii-viii: BRD service error
          collect_error(
            source: "#{source_prefix}/#{address_type}/country",
            title: 'Internal Server Error',
            detail: 'Failed To Obtain Country Types (Request Failed)'
          )
          return
        end

        # FES Val Section 5.b.vi: Invalid country
        return if countries.include?(address['country'])

        collect_error(
          source: "#{source_prefix}/#{address_type}/country",
          title: 'Invalid country',
          detail: "Provided country is not valid: #{address['country']}"
        )
      end

      def validate_international_postal_code!(mailing_address)
        country = mailing_address['country']
        return if country.blank?

        # FES Val Section 5.b.v: internationalPostalCode required for non-USA countries
        if country != 'USA' && mailing_address['internationalPostalCode'].blank?
          collect_error(
            source: '/veteranIdentification/mailingAddress/internationalPostalCode',
            detail: 'InternationalPostalCode is required for non-USA addresses'
          )
        end
      end

      # FES Val Section 5.c.i-ii: Date requirements validation
      def validate_change_of_address_dates!(change_of_address)
        if change_of_address['typeOfAddressChange'] == 'TEMPORARY'
          validate_temporary_address_dates!(change_of_address)
        elsif change_of_address['typeOfAddressChange'] == 'PERMANENT'
          validate_permanent_address_dates!(change_of_address)
        end
      end

      def validate_temporary_address_dates!(change_of_address)
        # FES Val Section 5.c.i: TEMPORARY requires beginDate and endDate
        dates = change_of_address['dates'] || {}

        if dates['beginDate'].blank?
          collect_error(
            source: '/changeOfAddress/dates/beginDate',
            detail: 'beginningDate is required for temporary address'
          )
        end

        if dates['endDate'].blank?
          collect_error(
            source: '/changeOfAddress/dates/endDate',
            detail: 'EndingDate is required for temporary address'
          )
        end
      end

      def validate_permanent_address_dates!(change_of_address)
        # FES Val Section 5.c.ii: PERMANENT cannot have endDate
        return if change_of_address.dig('dates', 'endDate').blank?

        collect_error(
          source: '/changeOfAddress/dates/endDate', detail: 'EndingDate cannot be provided for a permanent address'
        )
      end

      # FES Val Section 5.c.v-viii: Address field validations
      def validate_change_of_address_fields!(change_of_address)
        # Determine address type based on country field (schema doesn't have addressChangeType)
        country = change_of_address['country']

        if country == 'USA'
          # FES Val Section 5.c.v: DOMESTIC address validations
          validate_domestic_change_of_address!(change_of_address)
        elsif country.present?
          # FES Val Section 5.c.vi & 5.c.viii: INTERNATIONAL address validations
          validate_international_change_of_address!(change_of_address)
        end

        # NOTE: Military address fields don't exist in v2 schema
        # NOTE: FES Val Section 5.c.ix (country validation) is CROSSED OUT - not implementing
        # NOTE: FES Val Section 5.c.x (BRD error handling) is CROSSED OUT - not implementing
      end

      def validate_domestic_change_of_address!(change_of_address)
        validate_domestic_city!(change_of_address)
        validate_domestic_state!(change_of_address)
        validate_domestic_zip!(change_of_address)
      end

      def validate_domestic_city!(change_of_address)
        # FES Val Section 5.c.v: city, state and zipCode required for DOMESTIC
        return if change_of_address['city'].present?

        collect_error(
          source: '/changeOfAddress/city',
          detail: 'City is required'
        )
      end

      def validate_domestic_state!(change_of_address)
        # FES Val Section 5.c.v: city, state and zipCode required for DOMESTIC
        return if change_of_address['state'].present?

        collect_error(
          source: '/changeOfAddress/state',
          detail: 'State is required'
        )
      end

      def validate_domestic_zip!(change_of_address)
        # FES Val Section 5.c.v: city, state and zipCode required for DOMESTIC
        return if change_of_address['zipFirstFive'].present?

        collect_error(
          source: '/changeOfAddress/zipFirstFive',
          detail: 'ZipFirstFive is required'
        )
      end

      def validate_international_change_of_address!(change_of_address)
        validate_intl_change_city!(change_of_address)
        validate_intl_change_country!(change_of_address)
        validate_intl_change_postal_code!(change_of_address)
      end

      def validate_intl_change_city!(change_of_address)
        # FES Val Section 5.c.vi: city and country required for INTERNATIONAL
        return if change_of_address['city'].present?

        collect_error(
          source: '/changeOfAddress/city',
          detail: 'City is required'
        )
      end

      def validate_intl_change_country!(change_of_address)
        # FES Val Section 5.c.vi: city and country required for INTERNATIONAL
        return if change_of_address['country'].present?

        collect_error(
          source: '/changeOfAddress/country',
          detail: 'Country is required'
        )
      end

      def validate_intl_change_postal_code!(change_of_address)
        # FES Val Section 5.c.viii: internationalPostalCode required for INTERNATIONAL
        return if change_of_address['internationalPostalCode'].present?

        collect_error(
          source: '/changeOfAddress/internationalPostalCode',
          detail: 'InternationalPostalCode is required'
        )
      end

      ### FES Val Section 7: Disability action type validations
      def validate_disability_action_type_and_name!
        disabilities = form_attributes['disabilities']
        return if disabilities.blank?

        disabilities.each_with_index do |disability, index|
          validate_disability_action_type_none!(disability, index)
        end
      end

      # FES Val Section 7.f: disabilityActionType NONE is not supported
      def validate_disability_action_type_none!(disability, index)
        return unless disability['disabilityActionType'] == 'NONE'

        collect_error(
          source: "/disabilities/#{index}/disabilityActionType",
          detail: 'The request failed disability validation: The disability Action Type of "NONE" ' \
                  'is not currently supported.'
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

      def collect_error(source:, detail:, title: 'Unprocessable Entity')
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
