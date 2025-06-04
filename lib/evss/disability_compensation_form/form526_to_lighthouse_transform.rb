# frozen_string_literal: true

require 'disability_compensation/requests/form526_request_body'

module EVSS
  module DisabilityCompensationForm
    class Form526ToLighthouseTransform # rubocop:disable Metrics/ClassLength
      TOXIC_EXPOSURE_CAUSE_MAP = {
        NEW: 'My condition was caused by an injury or exposure during my military service.',
        WORSENED: 'My condition existed before I served in the military, but it got worse because of my military ' \
                  'service.',
        VA: 'My condition was caused by an injury or event that happened when I was receiving VA care.',
        SECONDARY: 'My condition was caused by another service-connected disability I already have.'
      }.freeze

      GULF_WAR_LOCATIONS = {
        afghanistan: 'Afghanistan',
        bahrain: 'Bahrain',
        egypt: 'Egypt',
        iraq: 'Iraq',
        israel: 'Israel',
        jordan: 'Jordan',
        kuwait: 'Kuwait',
        neutralzone: 'Neutral zone between Iraq and Saudi Arabia',
        oman: 'Oman',
        qatar: 'Qatar',
        saudiarabia: 'Saudi Arabia',
        somalia: 'Somalia',
        syria: 'Syria',
        uae: 'The United Arab Emirates (UAE)',
        turkey: 'Turkey',
        djibouti: 'Djibouti',
        lebanon: 'Lebanon',
        uzbekistan: 'Uzbekistan',
        yemen: 'Yemen',
        waters:
        'The waters of the Arabian Sea, Gulf of Aden, Gulf of Oman, Persian Gulf, and Red Sea',
        airspace: 'The airspace above any of these locations',
        none: 'None of these locations'
      }.freeze

      HERBICIDE_LOCATIONS = {
        cambodia: 'Cambodia at Mimot or Krek, Kampong Cham Province',
        guam: 'Guam, American Samoa, or their territorial waters',
        koreandemilitarizedzone: 'In or near the Korean demilitarized zone',
        johnston: 'Johnston Atoll or on a ship that called at Johnston Atoll',
        laos: 'Laos',
        c123: 'Somewhere you had contact with C-123 airplanes while serving in the Air Force or the Air Force Reserves',
        thailand: 'A U.S. or Royal Thai military base in Thailand',
        vietnam: 'Vietnam or the waters in or off of Vietnam ',
        none: 'None of these locations '
      }.freeze

      HAZARDS = {
        asbestos: 'Asbestos',
        chemical: 'SHAD - Shipboard Hazard and Defense',
        mos: 'Military Occupational Specialty-Related Toxin',
        mustardgas: 'Mustard Gas',
        radiation: 'Radiation',
        water: 'Contaminated Water At Camp Lejeune',
        none: 'None of these'
      }.freeze

      HAZARDS_LH_ENUM = {
        asbestos: 'ASBESTOS',
        chemical: 'SHIPBOARD_HAZARD_AND_DEFENSE',
        mos: 'MILITARY_OCCUPATIONAL_SPECIALTY_RELATED_TOXIN',
        mustardgas: 'MUSTARD_GAS',
        radiation: 'RADIATION',
        water: 'CONTAMINATED_WATER_AT_CAMP_LEJEUNE',
        other: 'OTHER'
      }.freeze

      MULTIPLE_EXPOSURES_TYPE = {
        gulf_war: 'gulf_war',
        herbicide: 'herbicide',
        hazard: 'hazard'
      }.freeze

      # takes known EVSS Form526Submission format and converts it to a Lighthouse request body
      # @param evss_data will look like JSON.parse(form526_submission.form_data)
      # @return Requests::Form526
      def transform(evss_data)
        form526 = evss_data['form526']
        lh_request_body = Requests::Form526.new
        lh_request_body.claimant_certification = true
        lh_request_body.claim_process_type = evss_claims_process_type(form526) # basic_info[:claim_process_type]

        transform_veteran_section(form526, lh_request_body)

        service_information = form526['serviceInformation']
        if service_information.present?
          lh_request_body.service_information = transform_service_information(service_information)
        end

        transform_disabilities_section(form526, lh_request_body)

        direct_deposit = form526['directDeposit']
        lh_request_body.direct_deposit = transform_direct_deposit(direct_deposit) if direct_deposit.present?

        treatments = form526['treatments']
        lh_request_body.treatments = transform_treatments(treatments) if treatments.present?

        service_pay = form526['servicePay']
        lh_request_body.service_pay = transform_service_pay(service_pay) if service_pay.present?

        toxic_exposure = form526['toxicExposure']
        lh_request_body.toxic_exposure = transform_toxic_exposure(toxic_exposure) if toxic_exposure.present?

        lh_request_body.claim_notes = form526['overflowText']
        lh_request_body
      end

      private

      # returns "STANDARD_CLAIM_PROCESS", "BDD_PROGRAM", or "FDC_PROGRAM"
      # based off of a few attributes in the evss data
      def evss_claims_process_type(form526)
        if form526['bddQualified']
          return 'BDD_PROGRAM'
        elsif form526['standardClaim']
          return 'STANDARD_CLAIM_PROCESS'
        end

        'FDC_PROGRAM'
      end

      def transform_veteran(veteran)
        veteran_identification = Requests::VeteranIdentification.new
        veteran_identification.current_va_employee = veteran['currentlyVAEmployee']
        veteran_identification.service_number = veteran['serviceNumber']
        veteran_identification.email_address = Requests::EmailAddress.new
        veteran_identification.email_address.email = veteran['emailAddress']
        veteran_identification.veteran_number = Requests::VeteranNumber.new

        fill_phone_number(veteran, veteran_identification)

        transform_mailing_address(veteran, veteran_identification) if veteran['currentMailingAddress'].present?

        veteran_identification
      end

      def transform_change_of_address(veteran)
        change_of_address = Requests::ChangeOfAddress.new
        change_of_address_source = veteran['changeOfAddress']
        change_of_address.city = change_of_address_source['militaryPostOfficeTypeCode'] ||
                                 change_of_address_source['city']
        change_of_address.state = change_of_address_source['militaryStateCode'] || change_of_address_source['state']
        change_of_address.country = change_of_address_source['country']
        change_of_address.address_line_1 = change_of_address_source['addressLine1']
        change_of_address.address_line_2 = change_of_address_source['addressLine2']
        change_of_address.address_line_3 = change_of_address_source['addressLine3']

        change_of_address.zip_first_five = change_of_address_source['zipFirstFive']
        change_of_address.zip_last_four = change_of_address_source['zipLastFour']
        change_of_address.international_postal_code = change_of_address_source['internationalPostalCode']
        change_of_address.type_of_address_change = change_of_address_source['addressChangeType']
        change_of_address.dates = Requests::Dates.new

        fill_change_of_address(change_of_address_source, change_of_address)

        change_of_address
      end

      def transform_homeless(veteran)
        homeless = Requests::Homeless.new
        homelessness = veteran['homelessness']

        fill_currently_homeless(homelessness, homeless) if homelessness['currentlyHomeless'].present?

        fill_risk_of_becoming_homeless(homelessness, homeless) if homelessness['homelessnessRisk'].present?

        homeless
      end

      def transform_service_information(service_information_source)
        service_information = Requests::ServiceInformation.new

        transform_service_periods(service_information_source, service_information)
        if service_information_source['confinements']
          transform_confinements(service_information_source, service_information)
        end
        if service_information_source['alternateNames']
          transform_alternate_names(service_information_source, service_information)
        end
        if service_information_source['reservesNationalGuardService']
          transform_reserves_national_guard_service(service_information_source, service_information)
          reserves_national_guard_service_source =
            service_information_source['reservesNationalGuardService']['title10Activation']
          if reserves_national_guard_service_source.present?
            # Title10Activation == FederalActivation
            service_information.federal_activation = Requests::FederalActivation.new(
              anticipated_separation_date: reserves_national_guard_service_source['anticipatedSeparationDate'],
              activation_date: reserves_national_guard_service_source['title10ActivationDate']
            )
          end
        end

        service_information
      end

      # Transforms EVSS treatments format into Lighthouse request treatments block format
      # @param treatments_source Array[{}] accepts a list of treatments in the EVSS treatments format
      def transform_treatments(treatments_source)
        treatments_source.map do |treatment|
          center = treatment['center']
          request_treatment = Requests::Treatment.new(
            treated_disability_names: treatment['treatedDisabilityNames'],
            center: Requests::Center.new(
              name: center['name'],
              state: center['state'],
              city: center['city']
            )
          )
          if treatment['startDate'].present?
            # LH spec says YYYY-DD or YYYY date format
            request_treatment.begin_date = convert_approximate_date(treatment['startDate'], short: true)
          end
          request_treatment
        end
      end

      # Transforms EVSS service pay format into Lighthouse request service pay block format
      # @param service_pay_source {} accepts an object in the EVSS servicePay format
      def transform_service_pay(service_pay_source)
        # mapping to target <- source
        service_pay_target = Requests::ServicePay.new

        service_pay_target.favor_training_pay = service_pay_source['waiveVABenefitsToRetainTrainingPay']
        service_pay_target.favor_military_retired_pay = service_pay_source['waiveVABenefitsToRetainRetiredPay']

        # map military retired pay block
        if service_pay_source['militaryRetiredPay'].present?
          transform_military_retired_pay(service_pay_source, service_pay_target)
        end

        # map separation pay block
        transform_separation_pay(service_pay_source, service_pay_target) if service_pay_source['separationPay'].present?

        service_pay_target
      end

      def transform_toxic_exposure(toxic_exposure_source) # rubocop:disable Metrics/MethodLength
        toxic_exposure_target = Requests::ToxicExposure.new

        gulf_war1990 = toxic_exposure_source['gulfWar1990']
        gulf_war2001 = toxic_exposure_source['gulfWar2001']
        herbicide = toxic_exposure_source['herbicide']
        other_herbicide_locations = toxic_exposure_source['otherHerbicideLocations']
        other_exposures = toxic_exposure_source['otherExposures']
        specify_other_exposures = toxic_exposure_source['specifyOtherExposures']

        if gulf_war1990.present? || gulf_war2001.present?
          toxic_exposure_target.gulf_war_hazard_service =
            transform_gulf_war(gulf_war1990, gulf_war2001)
        end

        if herbicide.present? || other_herbicide_locations.present?
          toxic_exposure_target.herbicide_hazard_service = transform_herbicide(herbicide,
                                                                               other_herbicide_locations)
        end

        if other_exposures.present? || specify_other_exposures.present?
          toxic_exposure_target.additional_hazard_exposures = transform_other_exposures(other_exposures,
                                                                                        specify_other_exposures)
        end

        # create an Array[Requests::MultipleExposures]
        multiple_exposures = []

        gulf_war1990_details = toxic_exposure_source['gulfWar1990Details']
        if gulf_war1990_details.present? && gulf_war1990.present?
          filtered_gulf_war1990_details = filtered_details(gulf_war1990, gulf_war1990_details)
          multiple_exposures += transform_multiple_exposures(filtered_gulf_war1990_details)
        end

        gulf_war2001_details = toxic_exposure_source['gulfWar2001Details']
        if gulf_war2001_details.present? && gulf_war2001.present?
          filtered_gulf_war2001_details = filtered_details(gulf_war2001, gulf_war2001_details)
          multiple_exposures += transform_multiple_exposures(filtered_gulf_war2001_details)
        end

        herbicide_details = toxic_exposure_source['herbicideDetails']
        if herbicide_details.present? && herbicide.present?
          filtered_herbicide_details = filtered_details(herbicide, herbicide_details)
          multiple_exposures += transform_multiple_exposures(filtered_herbicide_details,
                                                             MULTIPLE_EXPOSURES_TYPE[:herbicide])
        end

        if values_present(other_herbicide_locations) && other_herbicide_locations['description'].present?
          multiple_exposures +=
            transform_multiple_exposures_other_details(other_herbicide_locations,
                                                       MULTIPLE_EXPOSURES_TYPE[:herbicide])
        end

        other_exposures_details = toxic_exposure_source['otherExposuresDetails']
        if other_exposures_details.present? && other_exposures.present?
          filtered_other_exposures_details = filtered_details(other_exposures, other_exposures_details)
          multiple_exposures += transform_multiple_exposures(filtered_other_exposures_details,
                                                             MULTIPLE_EXPOSURES_TYPE[:hazard])
        end

        if values_present(specify_other_exposures) && specify_other_exposures['description'].present?
          multiple_exposures +=
            transform_multiple_exposures_other_details(specify_other_exposures,
                                                       MULTIPLE_EXPOSURES_TYPE[:hazard])
        end

        # multiple exposures could have repeated values that LH will not accept in the primary path.
        # remove them!
        multiple_exposures.uniq! do |exposure|
          [
            exposure.exposure_dates.begin_date,
            exposure.exposure_dates.end_date,
            exposure.exposure_location,
            exposure.hazard_exposed_to
          ]
        end

        toxic_exposure_target.multiple_exposures = multiple_exposures

        toxic_exposure_target
      end

      # @param details [Hash] the object with the exposure information of {location/hazard: {startDate, endDate}}
      # @param multiple_exposures_type [String] vets-website sends the key to be used as
      #   both a location and a hazard in different objects
      # @return Array[Requests::MultipleExposures] array of MultipleExposures or nil
      def transform_multiple_exposures(details, multiple_exposures_type = MULTIPLE_EXPOSURES_TYPE[:gulf_war])
        details&.map do |k, v|
          obj = Requests::MultipleExposures.new(
            exposure_dates: Requests::Dates.new
          )

          obj.exposure_dates.begin_date = convert_date_no_day(v['startDate']) if v['startDate'].present?
          obj.exposure_dates.end_date = convert_date_no_day(v['endDate']) if v['endDate'].present?

          if multiple_exposures_type == MULTIPLE_EXPOSURES_TYPE[:hazard]
            obj.hazard_exposed_to = HAZARDS[k.to_sym]
          elsif multiple_exposures_type == MULTIPLE_EXPOSURES_TYPE[:herbicide]
            obj.exposure_location = HERBICIDE_LOCATIONS[k.to_sym]
          else
            obj.exposure_location = GULF_WAR_LOCATIONS[k.to_sym]
          end

          obj
        end
      end

      def transform_multiple_exposures_other_details(details, multiple_exposures_type)
        obj = Requests::MultipleExposures.new(
          exposure_dates: Requests::Dates.new
        )

        obj.exposure_dates.begin_date = convert_date_no_day(details['startDate']) if details['startDate'].present?
        obj.exposure_dates.end_date = convert_date_no_day(details['endDate']) if details['endDate'].present?
        if details['description'].present?
          if multiple_exposures_type == MULTIPLE_EXPOSURES_TYPE[:hazard]
            obj.hazard_exposed_to = details['description']
          else
            obj.exposure_location = details['description']
          end
        end

        [obj]
      end

      # Filters a details object (i.e. gulfwar1990Details) of "false" or "unchecked" attributes from the source object
      # example:
      # {
      #   "gulfWar1990": {
      #     "afghanistan": true,
      #     "bahrain": true,
      #     "jordan": true,
      #     "kuwait": true,
      #     "iraq": true,
      #     "qatar": false #<- this should be removed from the matching details object
      #   },
      #   "gulfWar1990Details": {
      #     "iraq": {
      #       "startDate": "1991-03-01",
      #       "endDate": "1992-01-01"
      #     },
      #     "qatar": { #<- remove this
      #                "startDate": "1991-02-12",
      #                "endDate": "1991-06-01"
      #     },
      #     "kuwait": {
      #       "startDate": "1991-03-15"
      #     }
      #   }
      # }
      def filtered_details(source, details)
        details.select { |obj| source[obj].present? }
      end

      def transform_gulf_war(gulf_war1990, gulf_war2001)
        filtered_results1990 = gulf_war1990&.filter { |k| k != 'notsure' }
        gulf_war1990_value = filtered_results1990&.values&.any?(&:present?) && !none_of_these(filtered_results1990)
        filtered_results2001 = gulf_war2001&.filter { |k| k != 'notsure' }
        gulf_war2001_value = filtered_results2001&.values&.any?(&:present?) && !none_of_these(filtered_results2001)

        gulf_war_hazard_service = Requests::GulfWarHazardService.new
        gulf_war_hazard_service.served_in_gulf_war_hazard_locations =
          gulf_war1990_value || gulf_war2001_value ? 'YES' : 'NO'

        gulf_war_hazard_service
      end

      def transform_herbicide(herbicide, other_herbicide_locations)
        filtered_results_herbicide = herbicide&.filter { |k| k != 'notsure' }
        herbicide_value = (values_present(filtered_results_herbicide) ||
          (other_herbicide_locations.present? && other_herbicide_locations['description'].present?)) &&
                          !none_of_these(filtered_results_herbicide)

        herbicide_service = Requests::HerbicideHazardService.new
        herbicide_service.served_in_herbicide_hazard_locations = herbicide_value ? 'YES' : 'NO'

        herbicide_service
      end

      def transform_other_exposures(other_exposures, specify_other_exposures)
        if none_of_these(other_exposures) &&
           specify_other_exposures.present? && specify_other_exposures['description'].blank?
          return nil
        end

        filtered_results_other_exposures = other_exposures&.filter { |k, v| k != 'notsure' && v }
        additional_hazard_exposures_service = Requests::AdditionalHazardExposures.new
        unless none_of_these(filtered_results_other_exposures)
          additional_hazard_exposures_service.additional_exposures = filtered_results_other_exposures&.map do |k, _v|
            HAZARDS_LH_ENUM[k.to_sym]
          end
        end
        if specify_other_exposures.present? && specify_other_exposures['description'].present?
          other = HAZARDS_LH_ENUM[:other]
        end
        additional_hazard_exposures_service.additional_exposures << other if other.present?
        return nil if additional_hazard_exposures_service.additional_exposures == []

        additional_hazard_exposures_service
      end

      def values_present(obj)
        obj.present? && obj.values&.any?(&:present?)
      end

      def none_of_these(options)
        return false if options.blank?

        none_of_these = options['none']
        none_of_these.present?
      end

      def transform_disabilities_section(form526, lh_request_body)
        disabilities = form526['disabilities']
        toxic_exposure_conditions = form526['toxicExposure']['conditions'] if form526['toxicExposure'].present?
        lh_request_body.disabilities = transform_disabilities(disabilities, toxic_exposure_conditions)
      end

      def transform_veteran_section(form526, lh_request_body)
        veteran = form526['veteran']
        lh_request_body.veteran_identification = transform_veteran(veteran)
        lh_request_body.change_of_address = transform_change_of_address(veteran) if veteran['changeOfAddress'].present?
        lh_request_body.homeless = transform_homeless(veteran) if veteran['homelessness'].present?
      end

      def transform_separation_pay(service_pay_source, service_pay_target)
        separation_pay_source = service_pay_source['separationPay']

        if separation_pay_source.present?
          service_pay_target.retired_status = service_pay_source['retiredStatus']&.upcase
        end
        service_pay_target.received_separation_or_severance_pay =
          convert_nullable_bool(separation_pay_source['received'])

        separation_pay_payment_source = separation_pay_source['payment'] if separation_pay_source.present?
        if separation_pay_payment_source.present?
          service_pay_target.separation_severance_pay = Requests::SeparationSeverancePay.new(
            branch_of_service: separation_pay_payment_source['serviceBranch'],
            pre_tax_amount_received: separation_pay_payment_source['amount']
          )
          if separation_pay_source['receivedDate']
            service_pay_target.separation_severance_pay.date_payment_received =
              convert_approximate_date(separation_pay_source['receivedDate'])
          end
        end
      end

      def transform_military_retired_pay(service_pay_source, service_pay_target)
        military_retired_pay_source = service_pay_source['militaryRetiredPay']

        service_pay_target.receiving_military_retired_pay =
          convert_nullable_bool(military_retired_pay_source['receiving'])
        service_pay_target.future_military_retired_pay =
          convert_nullable_bool(military_retired_pay_source['willReceiveInFuture'])

        military_retired_pay_payment_source = military_retired_pay_source['payment']
        if military_retired_pay_payment_source.present?
          service_pay_target.military_retired_pay = Requests::MilitaryRetiredPay.new(
            branch_of_service: military_retired_pay_payment_source['serviceBranch'],
            monthly_amount: military_retired_pay_payment_source['amount']
          )
        end
      end

      def transform_confinements(service_information_source, service_information)
        service_information.confinements = service_information_source['confinements'].map do |confinement|
          Requests::Confinement.new(
            approximate_begin_date: confinement['confinementBeginDate'],
            approximate_end_date: confinement['confinementEndDate']
          )
        end
      end

      def transform_alternate_names(service_information_source, service_information)
        service_information.alternate_names = service_information_source['alternateNames'].map do |alternate_name|
          "#{alternate_name['firstName']} #{alternate_name['middleName']} #{alternate_name['lastName']}"
        end
      end

      def transform_reserves_national_guard_service(service_information_source, service_information)
        reserves_national_guard_service_source = service_information_source['reservesNationalGuardService']
        initialize_reserves_national_guard_service(reserves_national_guard_service_source, service_information)

        sorted_service_periods = sorted_service_periods(service_information_source).filter do |service_period|
          service_period['serviceBranch'].downcase.include?('reserves') ||
            service_period['serviceBranch'].downcase.include?('national guard')
        end

        if sorted_service_periods.first.present?
          component = convert_to_service_component(sorted_service_periods.first['serviceBranch'])
        end
        service_information.reserves_national_guard_service.component = component
      end

      def initialize_reserves_national_guard_service(reserves_national_guard_service_source, service_information)
        service_information.reserves_national_guard_service = Requests::ReservesNationalGuardService.new(
          obligation_terms_of_service: Requests::ObligationTermsOfService.new(
            begin_date: reserves_national_guard_service_source['obligationTermOfServiceFromDate'],
            end_date: reserves_national_guard_service_source['obligationTermOfServiceToDate']
          ),
          unit_name: reserves_national_guard_service_source['unitName'],
          receiving_inactive_duty_training_pay:
            convert_nullable_bool(reserves_national_guard_service_source['receivingInactiveDutyTrainingPay'])
        )

        if reserves_national_guard_service_source['unitPhone']
          service_information.reserves_national_guard_service.unit_phone = Requests::UnitPhone.new(
            area_code: reserves_national_guard_service_source['unitPhone']['areaCode'],
            phone_number: reserves_national_guard_service_source['unitPhone']['phoneNumber']
          )
        end
      end

      def transform_mailing_address(veteran, veteran_identification)
        veteran_identification.mailing_address = Requests::MailingAddress.new
        veteran_identification.mailing_address.address_line_1 = veteran['currentMailingAddress']['addressLine1']&.strip
        veteran_identification.mailing_address.address_line_2 = veteran['currentMailingAddress']['addressLine2']
        veteran_identification.mailing_address.address_line_3 = veteran['currentMailingAddress']['addressLine3']

        veteran_identification.mailing_address.city = veteran['currentMailingAddress']['militaryPostOfficeTypeCode'] ||
                                                      veteran['currentMailingAddress']['city']
        veteran_identification.mailing_address.state = veteran['currentMailingAddress']['militaryStateCode'] ||
                                                       veteran['currentMailingAddress']['state']
        veteran_identification.mailing_address.zip_first_five =
          veteran['currentMailingAddress']['zipFirstFive']
        veteran_identification.mailing_address.zip_last_four = veteran['currentMailingAddress']['zipLastFour']
        veteran_identification.mailing_address.country = veteran['currentMailingAddress']['country']
        veteran_identification.mailing_address.international_postal_code =
          veteran['currentMailingAddress']['internationalPostalCode']
      end

      def transform_service_periods(service_information_source, service_information)
        sorted_service_periods = sorted_service_periods(service_information_source)

        service_information.service_periods = sorted_service_periods.map do |service_period|
          Requests::ServicePeriod.new(
            service_branch: service_period['serviceBranch'],
            active_duty_begin_date: service_period['activeDutyBeginDate'],
            active_duty_end_date: service_period['activeDutyEndDate'],
            service_component: convert_to_service_component(service_period['serviceBranch'])
          )
        end

        service_information.service_periods.first.separation_location_code =
          service_information_source['separationLocationCode']
      end

      def sorted_service_periods(service_information_source)
        service_information_source['servicePeriods'].sort_by do |service_period|
          service_period['activeDutyEndDate']
        end.reverse
      end

      # returns either 'Active', 'Reserves' or 'National Guard' based on the service branch
      def convert_to_service_component(service_branch)
        service_branch = service_branch.downcase
        return 'Reserves' if service_branch.include?('reserves')
        return 'National Guard' if service_branch.include?('national guard')

        'Active'
      end

      # convert EVSS date object format into YYYY-MM-DD lighthouse string format
      # @param approximate_date_source Hash EVSS format data object
      # @param short boolean (optional) return a shortened date YYYY-MM
      def convert_approximate_date(approximate_date_source, short: false)
        approximate_date = approximate_date_source['year'].to_s
        approximate_date += "-#{approximate_date_source['month']}" if approximate_date_source['month']

        # returns YYYY-MM if only "short" date is requested
        return approximate_date if short

        approximate_date += "-#{approximate_date_source['day']}" if approximate_date_source['day']

        approximate_date
      end

      def transform_disabilities(disabilities_source, toxic_exposure_conditions)
        disabilities_source.map do |disability_source|
          dis = Requests::Disability.new
          dis.disability_action_type = disability_source['disabilityActionType']
          dis.name = disability_source['name']
          if toxic_exposure_conditions.present? && toxic_exposure_conditions.any?
            dis.is_related_to_toxic_exposure = is_related_to_toxic_exposure(dis.name, toxic_exposure_conditions)
          end
          dis.classification_code = disability_source['classificationCode'] if disability_source['classificationCode']
          dis.service_relevance = disability_source['serviceRelevance'] || ''
          dis.rated_disability_id = disability_source['ratedDisabilityId'] if disability_source['ratedDisabilityId']
          dis.diagnostic_code = disability_source['diagnosticCode'] if disability_source['diagnosticCode']
          if disability_source['secondaryDisabilities']
            dis.secondary_disabilities = transform_secondary_disabilities(disability_source)
          end
          if disability_source['cause'].present?
            dis.exposure_or_event_or_injury = format_exposure_text(disability_source['cause'],
                                                                   dis.is_related_to_toxic_exposure)
          end

          dis
        end
      end

      def format_exposure_text(cause, related_to_toxic_exposure)
        cause_text = TOXIC_EXPOSURE_CAUSE_MAP[cause.upcase.to_sym].dup
        related_to_toxic_exposure ? cause_text.sub!(/[.]?$/, '; toxic exposure.') : cause_text
      end

      # rubocop:disable Naming/PredicateName
      def is_related_to_toxic_exposure(condition_name, toxic_exposure_conditions)
        regex_non_word = /[^\w]/
        normalized_condition_name = condition_name.gsub(regex_non_word, '').downcase
        toxic_exposure_conditions[normalized_condition_name].present?
      end
      # rubocop:enable Naming/PredicateName

      def transform_secondary_disabilities(disability_source)
        disability_source['secondaryDisabilities'].map do |secondary_disability_source|
          sd = Requests::SecondaryDisability.new
          sd.disability_action_type = 'SECONDARY'
          sd.name = secondary_disability_source['name']
          if secondary_disability_source['classificationCode']
            sd.classification_code = secondary_disability_source['classificationCode']
          end
          sd.service_relevance = secondary_disability_source['serviceRelevance'] || ''
          sd
        end
      end

      def transform_direct_deposit(direct_deposit_source)
        direct_deposit = Requests::DirectDeposit.new
        if direct_deposit_source['bankName']
          direct_deposit.financial_institution_name = direct_deposit_source['bankName']
        end
        direct_deposit.account_type = direct_deposit_source['accountType'] if direct_deposit_source['accountType']
        direct_deposit.account_number = direct_deposit_source['accountNumber']&.strip
        direct_deposit.routing_number = direct_deposit_source['routingNumber']&.strip

        direct_deposit
      end

      # @param [Hash] veteran: veteran info in EVSS format
      # @param [Requests::Form526::VeteranIdentification] target: transform target
      def fill_phone_number(veteran, target)
        if veteran['daytimePhone'].present?
          target.veteran_number.telephone = veteran['daytimePhone']['areaCode'] +
                                            veteran['daytimePhone']['phoneNumber']
        end
      end

      def fill_change_of_address(change_of_address_source, change_of_address)
        # convert dates to YYYY-MM-DD
        if change_of_address_source['beginningDate'].present?
          change_of_address.dates.begin_date =
            convert_date(change_of_address_source['beginningDate'])
        end
        if change_of_address_source['endingDate'].present?
          change_of_address.dates.end_date =
            convert_date(change_of_address_source['endingDate'])
        end
      end

      # only needs currentlyHomeless from 'homelessness' source
      def fill_currently_homeless(source, target)
        options = source['currentlyHomeless']['homelessSituationType']&.strip
        send_other_description = options == 'OTHER'
        other_description = source['currentlyHomeless']['otherLivingSituation'] || nil
        target.currently_homeless = Requests::CurrentlyHomeless.new(
          homeless_situation_options: options,
          other_description: send_other_description ? other_description : nil
        )
        target.point_of_contact = source['pointOfContact']['pointOfContactName']
        primary_phone = source['pointOfContact']['primaryPhone']
        target.point_of_contact_number = Requests::ContactNumber.new(
          telephone: primary_phone['areaCode'] + primary_phone['phoneNumber']
        )
      end

      # needs whole `homelessness` object source
      def fill_risk_of_becoming_homeless(source, target)
        target.risk_of_becoming_homeless = Requests::RiskOfBecomingHomeless.new(
          living_situation_options: source['homelessnessRisk']['homelessnessRiskSituationType'],
          other_description: source['homelessnessRisk']['otherLivingSituation']
        )
        target.point_of_contact = source['pointOfContact']['pointOfContactName']
        primary_phone = source['pointOfContact']['primaryPhone']
        target.point_of_contact_number = Requests::ContactNumber.new(
          telephone: primary_phone['areaCode'] + primary_phone['phoneNumber']
        )
      end

      def convert_nullable_bool(boolean_value)
        return 'YES' if boolean_value == true
        return 'NO' if boolean_value == false

        # placing nil may not be necessary
        nil
      end

      def convert_date(date)
        Date.parse(date).strftime('%Y-%m-%d')
      end

      def convert_date_no_day(date)
        year = date[0, 4]
        month = date[5, 2]
        day = date[8, 2]

        # somehow, partial dates with the 'XX' (i.e. "2020-01-XX or 2020-XX-XX") are getting past FE validation
        # fix here in the backend while a proper FE solution is found
        return nil if year.downcase.include?('x')
        return year if month.blank? || month.upcase == 'XX'
        return "#{year}-#{month}" if day.blank? || day.upcase == 'XX'

        Date.parse(date).strftime('%Y-%m')
      end
    end
  end
end
