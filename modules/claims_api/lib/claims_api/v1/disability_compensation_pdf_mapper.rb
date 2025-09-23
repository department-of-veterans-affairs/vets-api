# frozen_string_literal: true

require_relative '../pdf_mapper_base'
require_relative 'mapper_helpers/auth_headers_lookup'
require_relative 'mapper_helpers/auto_claim_lookup'

module ClaimsApi
  module V1
    class DisabilityCompensationPdfMapper # rubocop:disable Metrics/ClassLength
      include PdfMapperBase
      include AuthHeadersLookup # get_auth_header
      include AutoClaimLookup # lookup_in_auto_claim

      SECTIONS = %i[
        section_0_claim_attributes
        section_1_veteran_identification
        section_2_change_of_address
        section_3_homeless_information
        section_5_disabilities
        section_5_treatment_centers
        section_6_service_information
        section_7_service_pay
        section_8_direct_deposit
      ].freeze

      HOMELESSNESS_RISK_SITUATION_TYPES = {
        'fleeing' => 'FLEEING_CURRENT_RESIDENCE',
        'shelter' => 'LIVING_IN_A_HOMELESS_SHELTER',
        'notShelter' => 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT',
        'anotherPerson' => 'STAYING_WITH_ANOTHER_PERSON',
        'other' => 'OTHER'
      }.freeze

      RISK_OF_BECOMING_HOMELESS_TYPES = {
        'losingHousing' => 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
        'leavingShelter' => 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE',
        'other' => 'OTHER'
      }.freeze

      def initialize(auto_claim, pdf_data, auth_headers, middle_initial)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
        @auth_headers = auth_headers&.deep_symbolize_keys
        @middle_initial = middle_initial
      end

      def map_claim
        SECTIONS.each { |section| send(section) }

        @pdf_data
      end

      private

      def section_0_claim_attributes
        claim_process_type = lookup_in_auto_claim(:standard_claim) ? 'STANDARD_CLAIM_PROCESS' : 'FDC_PROGRAM'
        claim_process_type = 'BDD_PROGRAM' if any_service_end_dates_in_bdd_window?

        @pdf_data[:data][:attributes][:claimProcessType] = claim_process_type
      end

      def any_service_end_dates_in_bdd_window?
        service_periods_data = lookup_in_auto_claim(:service_periods)
        service_periods_data.each do |sp|
          end_date = sp['activeDutyEndDate'].to_date
          if end_date >= 90.days.from_now.to_date && end_date <= 180.days.from_now.to_date
            set_pdf_data_for_section_one

            future_date = make_date_string_month_first(sp['activeDutyEndDate'], sp['activeDutyEndDate'].length)
            @pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty] = future_date
            return true
          end
        end

        false
      end

      def section_1_veteran_identification
        set_pdf_data_for_section_one

        mailing_address
        va_employee_status
        veteran_ssn
        veteran_file_number
        veteran_name
        veteran_birth_date

        @pdf_data
      end

      def mailing_address
        mailing_addr = lookup_in_auto_claim(:veteran_current_mailing_address)
        return if mailing_addr.blank?

        set_pdf_data_for_mailing_address

        address_base = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress]

        address_data = {
          numberAndStreet: concatenate_address(mailing_addr['addressLine1'], mailing_addr['addressLine2'],
                                               mailing_addr['addressLine3']),
          city: mailing_addr['city'],
          state: mailing_addr['state'],
          country: mailing_addr['country'],
          zip: concatenate_zip_code(mailing_addr)
        }.compact

        address_base.merge!(address_data)
      end

      def va_employee_status
        employee_status = lookup_in_auto_claim(:veteran_current_va_employee)
        return if employee_status.nil?

        @pdf_data[:data][:attributes][:identificationInformation][:currentVaEmployee] = employee_status
      end

      def veteran_ssn
        ssn = get_auth_header(:pnid)
        @pdf_data[:data][:attributes][:identificationInformation][:ssn] = format_ssn(ssn) if ssn.present?
      end

      def veteran_file_number
        file_number = get_auth_header(:birls_file_number)
        @pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber] = file_number
      end

      def veteran_name
        set_veteran_name

        fname = get_auth_header(:first_name)
        lname = get_auth_header(:last_name)

        @pdf_data[:data][:attributes][:identificationInformation][:name][:firstName] = fname
        @pdf_data[:data][:attributes][:identificationInformation][:name][:lastName] = lname
        @pdf_data[:data][:attributes][:identificationInformation][:name][:middleInitial] = @middle_initial
      end

      def veteran_birth_date
        birth_date_data = get_auth_header(:birth_date)
        birth_date = format_birth_date(birth_date_data) if birth_date_data

        @pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth] = birth_date
      end

      def set_pdf_data_for_section_one
        return if @pdf_data[:data][:attributes].key?(:identificationInformation)

        @pdf_data[:data][:attributes][:identificationInformation] = {}
      end

      def set_pdf_data_for_mailing_address
        return if @pdf_data[:data][:attributes][:identificationInformation].key?(:mailingAddress)

        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress] = {}
      end

      def set_veteran_name
        @pdf_data[:data][:attributes][:identificationInformation][:name] = {}
      end

      def section_2_change_of_address
        address_info = lookup_in_auto_claim(:veteran_change_of_address)
        return if address_info.blank?

        set_pdf_data_for_section_two

        change_of_address_dates(address_info)
        change_of_address_location(address_info)
        change_of_address_type(address_info)
      end

      def set_pdf_data_for_section_two
        @pdf_data[:data][:attributes][:changeOfAddress] = {}
      end

      def change_of_address_dates(address_info)
        set_pdf_data_for_change_of_address_dates

        start_date = address_info&.dig('beginningDate')
        end_date = address_info&.dig('endingDate')

        if start_date.present? # This is required but checking to be safe anyways
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:start] =
            make_date_object(start_date, start_date.length)
        end
        if end_date.present?
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end] =
            make_date_object(end_date, end_date.length)
        end
      end

      def set_pdf_data_for_change_of_address_dates
        return if @pdf_data[:data][:attributes][:changeOfAddress]&.key?(:effectiveDates)

        @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates] = {}
      end

      def change_of_address_location(address_info)
        set_pdf_data_for_change_of_address_location

        number_and_street = concatenate_address(address_info['addressLine1'], address_info['addressLine2'])
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet] = number_and_street

        city = address_info&.dig('city')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city] = city if city.present?

        state = address_info&.dig('state')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state] = state if state.present?

        zip = concatenate_zip_code(address_info)
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:zip] = zip if zip.present?

        # required
        country = address_info&.dig('country')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:country] = format_country(country)
      end

      def set_pdf_data_for_change_of_address_location
        return if @pdf_data[:data][:attributes][:changeOfAddress]&.key?(:newAddress)

        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress] = {}
      end

      def change_of_address_type(address_info)
        @pdf_data[:data][:attributes][:changeOfAddress][:typeOfAddressChange] = address_info&.dig('addressChangeType')
      end

      def section_3_homeless_information
        homeless_info = lookup_in_auto_claim(:veteran_homelessness)
        return if homeless_info.blank?

        set_pdf_data_for_homeless_information

        point_of_contact
        currently_homeless
        homelessness_risk
      end

      def set_pdf_data_for_homeless_information
        return if @pdf_data[:data][:attributes].key?(:homelessInformation)

        @pdf_data[:data][:attributes][:homelessInformation] = {}
      end

      # If "pointOfContact" is on the form "pointOfContactName", "primaryPhone" are required via the schema
      # "primaryPhone" requires both "areaCode" and "phoneNumber" via the schema
      def point_of_contact
        point_of_contact_info = lookup_in_auto_claim(:veteran_homelessness_point_of_contact)
        return if point_of_contact_info.blank?

        @pdf_data[:data][:attributes][:homelessInformation][:pointOfContact] =
          point_of_contact_info&.dig('pointOfContactName')
        phone_object = point_of_contact_info&.dig('primaryPhone')
        phone_number = phone_object.values.join

        @pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber] =
          { telephone: convert_phone(phone_number) }
      end

      # if "currentlyHomeless" is present "homelessSituationType", "otherLivingSituation" are required by the schema
      def currently_homeless
        currently_homeless_info = lookup_in_auto_claim(:veteran_homelessness_currently_homeless)
        return if currently_homeless_info.blank?

        set_pdf_data_for_currently_homeless_information
        currently_homeless_base = @pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

        currently_homeless_base[:homelessSituationOptions] =
          HOMELESSNESS_RISK_SITUATION_TYPES[currently_homeless_info['homelessSituationType']]
        currently_homeless_base[:otherDescription] = currently_homeless_info['otherLivingSituation']
      end

      def set_pdf_data_for_currently_homeless_information
        return if @pdf_data[:data][:attributes][:homelessInformation]&.key?(:currentlyHomeless)

        @pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless] = {}
      end

      # if "homelessnessRisk" is on the submission "homelessnessRiskSituationType", "otherLivingSituation" are required
      def homelessness_risk
        homelessness_risk_info = lookup_in_auto_claim(:veteran_homelessness_risk)
        return if homelessness_risk_info.blank?

        set_pdf_data_for_homelessness_risk_information
        risk_of_homeless_base = @pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless]

        risk_of_homeless_base[:livingSituationOptions] =
          RISK_OF_BECOMING_HOMELESS_TYPES[homelessness_risk_info['homelessnessRiskSituationType']]
        risk_of_homeless_base[:otherDescription] = homelessness_risk_info['otherLivingSituation']
      end

      def set_pdf_data_for_homelessness_risk_information
        return if @pdf_data[:data][:attributes][:homelessInformation]&.key?(:riskOfBecomingHomeless)

        @pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless] = {}
      end

      # Section 4 has no mapped properties in v1

      # "disabilities" are required
      # "disabilityActionType", "name" are required inside "disabilities" via the schema
      def section_5_disabilities
        set_pdf_data_for_claim_information
        set_pdf_data_for_disabilities

        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = transform_disabilities
      end

      def set_pdf_data_for_claim_information
        return if @pdf_data[:data][:attributes]&.key?(:claimInformation)

        @pdf_data[:data][:attributes][:claimInformation] = {}
      end

      def set_pdf_data_for_disabilities
        return if @pdf_data[:data][:attributes][:claimInformation]&.key?(:disabilities)

        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = {}
      end

      def transform_disabilities
        disabilities_data = lookup_in_auto_claim(:disabilities)
        disabilities_data.flat_map do |disability|
          primary_disability = build_primary_disability(disability)
          secondary_disabilities = if disability['secondaryDisabilities'].present?
                                     build_secondary_disabilities(disability)
                                   end

          [primary_disability, *secondary_disabilities]
        end
      end

      def build_primary_disability(disability)
        dis_name = disability['name']
        dis_date = format_disability_date(disability['approximateBeginDate'])
        service_relevance = disability['serviceRelevance']

        build_disability_item(dis_name, dis_date, service_relevance)
      end

      def build_secondary_disabilities(disability)
        disability['secondaryDisabilities'].map do |secondary_disability|
          dis_name = "#{secondary_disability['name']} secondary to: #{disability['name']}"
          dis_date = format_disability_date(secondary_disability['approximateBeginDate'])
          service_relevance = secondary_disability['serviceRelevance']

          build_disability_item(dis_name, dis_date, service_relevance)
        end
      end

      def format_disability_date(begin_date)
        return nil if begin_date.blank?

        make_date_string_month_first(begin_date, begin_date.length)
      end

      # 'treatments' is optional
      # If 'treatments' is provided 'treatedDisabilityNames' and 'center' are required via the schema
      def section_5_treatment_centers
        treatment_info = lookup_in_auto_claim(:treatments)
        return if treatment_info.blank?

        set_pdf_data_for_claim_information
        set_pdf_data_for_treatments

        treatments = get_treatments(treatment_info)
        treatment_details = treatments.map(&:deep_symbolize_keys)

        @pdf_data[:data][:attributes][:claimInformation][:treatments] = treatment_details
      end

      def set_pdf_data_for_treatments
        return if @pdf_data[:data][:attributes][:claimInformation]&.key?(:treatments)

        @pdf_data[:data][:attributes][:claimInformation][:treatments] = {}
      end

      def get_treatments(treatment_info)
        [].tap do |treatments_list|
          treatment_info.map do |tx|
            treatment_details = build_treatment_details(tx)
            treatment_start_date = build_treatment_start_date(tx)
            do_not_have_date = treatment_start_date.blank? || nil

            treatments_list << build_treatment_item(treatment_details, treatment_start_date, do_not_have_date)
          end
        end.flatten
      end

      # String that is a composite of the treatment name and center name
      def build_treatment_details(treatment)
        if treatment['center'].present?
          center_data = treatment['center'].transform_keys(&:to_sym)
          center = center_data.values_at(:name, :country).compact.map(&:presence).compact.join(', ')
        end

        names = treatment['treatedDisabilityNames']
        name = names.join(', ') if names.present?
        [name, center].compact.join(' - ')
      end

      def build_treatment_start_date(treatment)
        return if treatment['startDate'].blank?

        start_date = parse_treatment_date(treatment['startDate'])
        make_date_object(start_date, start_date.length)
      end

      # The PDF Generator only wants month and year for this field
      # The date value sent in is in the format of YYYY-MM-DD
      def parse_treatment_date(date)
        date.length > 7 ? date[0..-4] : date
      end

      def build_treatment_item(treatment_details, treatment_start_date, do_not_have_date)
        { treatmentDetails: treatment_details, dateOfTreatment: treatment_start_date,
          doNotHaveDate: do_not_have_date }.compact
      end

      def section_6_service_information
        set_pdf_data_for_service_information

        service_periods

        confinements if @auto_claim.dig('serviceInformation', 'confinements')
        reserves_national_guard_service if lookup_in_auto_claim(:reserves_service)
        alternate_names if lookup_in_auto_claim(:reserves_alternate_names)
      end

      def set_pdf_data_for_service_information
        return if @pdf_data[:data][:attributes]&.key?(:serviceInformation)

        @pdf_data[:data][:attributes][:serviceInformation] = {}
      end

      # 'serviceBranch', 'activeDutyBeginDate' & 'activeDutyEndDate' are required via the schema
      def service_periods
        set_pdf_data_for_most_recent_service_period
        service_periods_data = lookup_in_auto_claim(:service_periods)

        most_recent_service_period_data = service_periods_data.max_by do |sp|
          sp['activeDutyEndDate'].presence || {}
        end
        most_recent_branch = most_recent_service_period_data['serviceBranch']
        most_recent_service_period(most_recent_service_period_data, most_recent_branch)

        remaining_periods = service_periods_data - [most_recent_service_period_data]
        additional_service_periods(remaining_periods) if remaining_periods
      end

      def set_pdf_data_for_most_recent_service_period
        return if @pdf_data[:data][:attributes][:serviceInformation]&.key?(:mostRecentActiveService)

        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
      end

      # 'separationLocationCode' is optional
      def most_recent_service_period(service_period, branch)
        location_code = service_period['separationLocationCode']
        begin_date = service_period['activeDutyBeginDate']
        end_date = service_period['activeDutyEndDate']

        @pdf_data[:data][:attributes][:serviceInformation][:branchOfService] = { branch: }
        if location_code
          @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
            location_code
        end
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:start] = make_date_object(
          begin_date, begin_date.length
        )
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:end] = make_date_object(
          end_date, end_date.length
        )
      end

      def additional_service_periods(remaining_periods)
        additional_periods = []
        remaining_periods.each do |rp|
          start_date = make_date_object(rp['activeDutyBeginDate'], rp['activeDutyBeginDate'].length)
          end_date = make_date_object(rp['activeDutyEndDate'], rp['activeDutyEndDate'].length)

          additional_periods << {
            start: start_date,
            end: end_date
          }
        end
        @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = additional_periods
      end

      def confinements
        set_pdf_data_for_pow_confinement

        confinement_periods
      end

      def set_pdf_data_for_pow_confinement
        return if @pdf_data[:data][:attributes][:serviceInformation]&.key?(:prisonerOfWarConfinement)

        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] = {}
      end

      # 'confinementBeginDate' & 'confinementEndDate' are required via the schema if confinements are present
      def confinement_periods
        confinements_data = @auto_claim.dig('serviceInformation', 'confinements')

        periods_of_confinement = []
        confinements_data.each do |c|
          begin_date = make_date_object(c['confinementBeginDate'], c['confinementBeginDate'].length)
          end_date = make_date_object(c['confinementEndDate'], c['confinementEndDate'].length)

          periods_of_confinement << { start: begin_date, end: end_date }
        end
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] =
          { confinementDates: periods_of_confinement }
      end

      # If reserves are present
      # 'obligationTermOfServiceFromDate', 'obligationTermOfServiceToDate' & 'unitName' are required via the schema
      def reserves_national_guard_service
        set_pdf_data_for_serves_national_guard_service

        required_reserves_data
        optional_reserves_data
      end

      def set_pdf_data_for_serves_national_guard_service
        return if @pdf_data[:data][:attributes][:serviceInformation]&.key?(:reservesNationalGuardService)

        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService] = {}
      end

      def required_reserves_data
        reserves_data_object_base = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        unit_name = lookup_in_auto_claim(:reserves_unit_name)
        begin_date = lookup_in_auto_claim(:reserves_obligation_from)
        end_date = lookup_in_auto_claim(:reserves_obligation_to)

        reserves_data_object_base[:unitName] = unit_name
        reserves_data_object_base[:obligationTermsOfService] = {
          start: make_date_object(begin_date, begin_date.length),
          end: make_date_object(end_date, end_date.length)
        }
      end

      def optional_reserves_data
        reserves_data = lookup_in_auto_claim(:reserves_service)

        unit_phone(reserves_data) if reserves_data['unitPhone']
        inactive_duty_training_pay(reserves_data) if reserves_data.key?('receivingInactiveDutyTrainingPay')
        title_10_activation if reserves_data['title10Activation']
      end

      def unit_phone(reserves_data)
        if reserves_data&.dig('unitPhone')
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhoneNumber] = [
            reserves_data&.dig('unitPhone', 'areaCode'),
            reserves_data&.dig('unitPhone', 'phoneNumber')&.tr('-', '')
          ].compact.join
        end
      end

      def inactive_duty_training_pay(reserves_data)
        reserves_data_object_base = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        reserves_data_object_base[:receivingInactiveDutyTrainingPay] =
          handle_yes_no(reserves_data['receivingInactiveDutyTrainingPay'])
      end

      # if 'title_10_activation' is present
      # 'anticipatedSeparationDate' & 'title10ActivationDate'
      def title_10_activation
        title_10_data = lookup_in_auto_claim(:reserves_title_10_activation)
        activation_date_data = title_10_data['title10ActivationDate']
        anticipated_separation_date_data = title_10_data['anticipatedSeparationDate']
        activation_date = make_date_object(activation_date_data, activation_date_data.length)
        anticipated_separation_date = make_date_object(
          anticipated_separation_date_data, anticipated_separation_date_data.length
        )

        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:federalActivation] = {
          activationDate: activation_date,
          anticipatedSeparationDate: anticipated_separation_date
        }
      end

      def alternate_names
        alt_names = lookup_in_auto_claim(:reserves_alternate_names)

        names = alt_names.map do |n|
          n.values_at('firstName', 'middleName', 'lastName').compact.join(' ')
        end

        @pdf_data[:data][:attributes][:serviceInformation][:alternateNames] = names
      end

      def section_7_service_pay
        return unless lookup_in_auto_claim(:service_pay)

        set_pdf_data_for_service_pay

        service_pay_base = @pdf_data[:data][:attributes][:servicePay]
        claim_service_pay_data = lookup_in_auto_claim(:service_pay)

        training_pay = lookup_in_auto_claim(:service_pay_retain_training_pay)
        if claim_service_pay_data.key?('waiveVABenefitsToRetainTrainingPay')
          service_pay_base[:favorTrainingPay] = training_pay
        end

        retain_retired_pay = lookup_in_auto_claim(:service_pay_retain_retired_pay)
        if claim_service_pay_data.key?('waiveVABenefitsToRetainRetiredPay')
          service_pay_base[:favorMilitaryRetiredPay] = retain_retired_pay
        end

        military_retired_pay = lookup_in_auto_claim(:service_pay_military_retired_pay)
        map_military_retired_pay(military_retired_pay, service_pay_base) if military_retired_pay.present?

        map_separation_pay if lookup_in_auto_claim(:service_pay_separation_pay)
      end

      def set_pdf_data_for_service_pay
        return if @pdf_data[:data][:attributes]&.key?(:servicePay)

        @pdf_data[:data][:attributes][:servicePay] = {}
      end

      # if 'militaryRetiredPay' is included
      # 'receiving' & 'payment' are required via the schema
      def map_military_retired_pay(military_retired_pay_data, service_pay_base)
        retired_pay = lookup_in_auto_claim(:service_pay_receiving_retired_pay)
        service_pay_base[:receivingMilitaryRetiredPay] = handle_yes_no(retired_pay)

        future_retired_pay = lookup_in_auto_claim(:service_pay_future_military_pay)
        if military_retired_pay_data.key?('willReceiveInFuture')
          service_pay_base[:futureMilitaryRetiredPay] = handle_yes_no(future_retired_pay)
        end

        explanation = lookup_in_auto_claim(:service_pay_future_pay_explanation)
        service_pay_base[:futureMilitaryRetiredPayExplanation] = explanation if explanation

        retired_pay_payment if lookup_in_auto_claim(:military_retired_pay_payment)
      end

      # if 'payment' is included
      # 'serviceBranch' is required via the schema
      def retired_pay_payment
        set_pdf_path_for_military_retired_pay

        retired_branch_of_service = lookup_in_auto_claim(:military_retired_pay_service_branch)
        @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay][:branchOfService] =
          { branch: retired_branch_of_service }

        retired_pay_amount = lookup_in_auto_claim(:military_retired_pay_amount)
        if retired_pay_amount
          @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay][:monthlyAmount] =
            retired_pay_amount
        end
      end

      def set_pdf_path_for_military_retired_pay
        return if @pdf_data[:data][:attributes][:servicePay]&.key?(:militaryRetiredPay)

        @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay] = {}
      end

      # if 'separationPay' is included
      # 'received' is required via the schema
      def map_separation_pay
        serverance_or_separation_pay = lookup_in_auto_claim(:service_pay_separation_or_severance_pay_received)
        @pdf_data[:data][:attributes][:servicePay][:receivedSeparationOrSeverancePay] =
          handle_yes_no(serverance_or_separation_pay)

        set_separation_severance_pay_pdf_data

        received_date = lookup_in_auto_claim(:separation_pay_received_date)
        if received_date
          @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:datePaymentReceived] =
            make_date_object(received_date, received_date.length)
        end

        separation_pay_branch = lookup_in_auto_claim(:separation_pay_branch_of_service)
        if separation_pay_branch
          @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:branchOfService] =
            { branch: separation_pay_branch }
        end

        amount = lookup_in_auto_claim(:separation_pay_amount)
        @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:preTaxAmountReceived] = amount if amount
      end

      def set_separation_severance_pay_pdf_data
        return if @pdf_data[:data][:attributes][:servicePay]&.key?(:separationSeverancePay)

        @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay] = {}
      end

      # if 'drectDeposit' is included
      # 'accountType', 'accountNumber' & 'routingNumber' are required via the schema
      def section_8_direct_deposit
        return unless lookup_in_auto_claim(:direct_deposit)

        set_direct_deposit_pdf_data

        direct_deposit_required_fields
        direct_deposit_optional_fields if lookup_in_auto_claim(:direct_deposit_bank_name)
      end

      def direct_deposit_required_fields
        @pdf_data[:data][:attributes][:directDepositInformation][:accountType] =
          lookup_in_auto_claim(:direct_deposit_account_type)
        @pdf_data[:data][:attributes][:directDepositInformation][:accountNumber] =
          lookup_in_auto_claim(:direct_deposit_account_number)
        @pdf_data[:data][:attributes][:directDepositInformation][:routingNumber] =
          lookup_in_auto_claim(:direct_deposit_routing_number)
      end

      def direct_deposit_optional_fields
        @pdf_data[:data][:attributes][:directDepositInformation][:financialInstitutionName] =
          lookup_in_auto_claim(:direct_deposit_bank_name)
      end

      def set_direct_deposit_pdf_data
        return if @pdf_data[:data][:attributes]&.key?(:directDepositInformation)

        @pdf_data[:data][:attributes][:directDepositInformation] = {}
      end
    end
  end
end
