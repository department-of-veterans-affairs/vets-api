# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper # rubocop:disable Metrics/ClassLength
      NATIONAL_GUARD_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES'
      }.freeze

      SERVICE_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES',
        'Active' => 'ACTIVE'
      }.freeze

      def initialize(auto_claim, pdf_data, target_veteran)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
        @target_veteran = target_veteran
      end

      def map_claim
        claim_attributes
        toxic_exposure_attributes
        homeless_attributes
        veteran_info
        chg_addr_attributes if @auto_claim['changeOfAddress'].present?
        service_info
        disability_attributes
        treatment_centers
        get_service_pay
        direct_deposit_information

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim&.deep_symbolize_keys
        @pdf_data[:data][:attributes].delete(:claimantCertification)
        claim_date_and_signature

        @pdf_data
      end

      def homeless_attributes
        if @auto_claim&.dig('homeless').present?
          @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim&.dig('homeless')&.deep_symbolize_keys
          @pdf_data&.dig(:data, :attributes, :homelessInformation).present?
          homeless_point_of_contact_telephone =
            @pdf_data[:data][:attributes][:homeless][:pointOfContactNumber][:telephone]
          homeless_point_of_contact_international =
            @pdf_data[:data][:attributes][:homeless][:pointOfContactNumber][:internationalTelephone]
          @pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:telephone] =
            homeless_point_of_contact_telephone
          if homeless_point_of_contact_international
            @pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:internationalTelephone] =
              homeless_point_of_contact_international
          end
        end
        @pdf_data[:data][:attributes].delete(:homeless)
        homeless_at_risk_or_currently

        @pdf_data
      end

      def homeless_at_risk_or_currently
        at_risk = @auto_claim&.dig('homeless', 'riskOfBecomingHomeless', 'livingSituationOptions').present?
        currently = @auto_claim&.dig('homeless', 'pointOfContact').present?

        if currently && !at_risk
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: 'YES')
        else
          homeless = @pdf_data[:data][:attributes][:homelessInformation].present?
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: 'YES') if homeless
        end

        @pdf_data
      end

      def chg_addr_attributes # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim&.dig('changeOfAddress')&.deep_symbolize_keys

        country = @pdf_data[:data][:attributes][:changeOfAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(
          newAddress: { country: abbr_country }
        )
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(
          effectiveDates: {
            start:
            convert_date_string_mdy_to_object(@pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginDate])
          }
        )
        @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end] =
          convert_date_string_mdy_to_object(@pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate])
        number_and_street = @pdf_data[:data][:attributes][:changeOfAddress][:numberAndStreet]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet] = number_and_street
        apartment_or_unit_number = @pdf_data[:data][:attributes][:changeOfAddress][:apartmentOrUnitNumber]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:apartmentOrUnitNumber] = apartment_or_unit_number
        city = @pdf_data[:data][:attributes][:changeOfAddress][:city]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city] = city
        state = @pdf_data[:data][:attributes][:changeOfAddress][:state]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state] = state
        chg_addr_zip
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:beginDate)
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:endDate)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:dates)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:numberAndStreet)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:apartmentOrUnitNumber)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:city)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:state)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipLastFour)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:country)

        @pdf_data
      end

      def chg_addr_zip
        zip_first_five = (@auto_claim&.dig('changeOfAddress', 'zipFirstFive') || '')
        zip_last_four = (@auto_claim&.dig('changeOfAddress', 'zipLastFour') || '')
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              else
                zip_first_five
              end
        addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress].merge!(zip:) if addr
      end

      def toxic_exposure_attributes
        @pdf_data[:data][:attributes].merge!(
          exposureInformation: { toxicExposure: @auto_claim&.dig('toxicExposure')&.deep_symbolize_keys }
        )
        gulfwar_hazard
        herbicide_hazard
        additional_exposures
        multiple_exposures
        @pdf_data[:data][:attributes].delete(:toxicExposure)

        @pdf_data
      end

      # rubocop:disable Layout/LineLength
      def gulfwar_hazard
        gulf = @pdf_data&.dig(:data, :attributes, :toxicExposure, :gulfWarHazardService).present?
        if gulf
          gulfwar_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:start] =
            convert_date_string_my_to_object(gulfwar_service_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:beginDate)
          gulfwar_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:end] =
            convert_date_string_my_to_object(gulfwar_service_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:endDate)
          served_in_gulf_war_hazard_locations = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations] =
            served_in_gulf_war_hazard_locations ? 'YES' : 'NO'
        end
      end

      def herbicide_hazard
        herb = @pdf_data&.dig(:data, :attributes, :toxicExposure, :herbicideHazardService).present?
        if herb
          herbicide_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:start] =
            convert_date_string_my_to_object(herbicide_service_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:beginDate)
          herbicide_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:end] =
            convert_date_string_my_to_object(herbicide_service_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:endDate)
          served_in_herbicide_hazard_locations = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations] =
            served_in_herbicide_hazard_locations ? 'YES' : 'NO'
        end
      end

      def additional_exposures
        add = @pdf_data&.dig(:data, :attributes, :toxicExposure, :additionalHazardExposures).present?
        if add
          additional_exposure_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:beginDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:start] =
            convert_date_string_my_to_object(additional_exposure_dates_begin)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:beginDate)
          additional_exposure_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:endDate]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:end] =
            convert_date_string_my_to_object(additional_exposure_dates_end)
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:endDate)
        end
      end

      def multiple_exposures
        multi = @pdf_data&.dig(:data, :attributes, :toxicExposure, :multipleExposures).present?
        if multi
          @pdf_data[:data][:attributes][:toxicExposure][:multipleExposures].each_with_index do |exp, index|
            multiple_service_dates_begin = exp[:exposureDates][:beginDate]
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:start] = convert_date_string_my_to_object(multiple_service_dates_begin)
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:beginDate)
            multiple_service_dates_end = exp[:exposureDates][:endDate]
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:end] = convert_date_string_my_to_object(multiple_service_dates_end)
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:endDate)
          end
        end
        @pdf_data
      end

      def veteran_info # rubocop:disable Metrics/MethodLength
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim&.dig('veteranIdentification')&.deep_symbolize_keys
        )
        vet_number = @pdf_data[:data][:attributes][:identificationInformation][:veteranNumber].present?
        if vet_number
          phone = @pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:telephone]
          international_telephone =
            @pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:internationalTelephone]
        end
        if phone
          @pdf_data[:data][:attributes][:identificationInformation].merge!(
            phoneNumber: { telephone: phone }
          )
        end
        if international_telephone
          @pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:internationalTelephone] =
            international_telephone
        end
        @pdf_data[:data][:attributes][:identificationInformation].delete(:veteranNumber)
        country = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country] = abbr_country
        zip
        @pdf_data[:data][:attributes].delete(:veteranIdentification)

        @pdf_data
      end

      def zip
        zip_first_five = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipFirstFive') || '')
        zip_last_four = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipLastFour') || '')
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              else
                zip_first_five
              end
        mailing_addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:) if mailing_addr
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipLastFour)

        @pdf_data
      end

      def disability_attributes
        @pdf_data[:data][:attributes][:claimInformation] = {}
        @pdf_data[:data][:attributes][:claimInformation].merge!(
          { disabilities: [] }
        )
        disabilities = transform_disabilities

        details = disabilities[:data][:attributes][:claimInformation][:disabilities].map(
          &:deep_symbolize_keys
        )
        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = details

        conditions_related_to_exposure?
        @pdf_data[:data][:attributes].delete(:disabilities)
        @pdf_data
      end

      def transform_disabilities # rubocop:disable Metrics/MethodLength
        d2 = []
        claim_disabilities = @auto_claim&.dig('disabilities')&.map do |disability|
          disability['disability'] = disability['name']
          if disability['approximateDate'].present?
            approx_date = if disability['approximateDate'].length == 7
                            Date.strptime(disability['approximateDate'], '%m-%Y')
                          else
                            Date.strptime(disability['approximateDate'], '%m-%d-%Y')
                          end
            disability['approximateDate'] = approx_date.strftime('%B %Y')
          end
          disability.delete('name')
          disability.delete('classificationCode')
          disability.delete('ratedDisabilityId')
          disability.delete('diagnosticCode')
          disability.delete('disabilityActionType')
          sec_dis = disability['secondaryDisabilities']&.map do |secondary_disability|
            secondary_disability['disability'] = secondary_disability['name']
            if secondary_disability['approximateDate'].present?
              approx_date = if secondary_disability['approximateDate'].length == 7
                              Date.strptime(secondary_disability['approximateDate'], '%m-%Y')
                            else
                              Date.strptime(secondary_disability['approximateDate'], '%m-%d-%Y')
                            end
              secondary_disability['approximateDate'] = approx_date.strftime('%B %Y')
            end
            secondary_disability.delete('name')
            secondary_disability.delete('classificationCode')
            secondary_disability.delete('ratedDisabilityId')
            secondary_disability.delete('diagnosticCode')
            secondary_disability.delete('disabilityActionType')
            secondary_disability
          end
          d2 << sec_dis
          disability.delete('secondaryDisabilities')
          disability
        end
        claim_disabilities << d2
        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = claim_disabilities.flatten.compact

        @pdf_data
      end

      def conditions_related_to_exposure?
        # If any disability is included in the request with 'isRelatedToToxicExposure' set to true,
        # set exposureInformation.hasConditionsRelatedToToxicExposures to true.
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] = nil
        has_conditions = @pdf_data[:data][:attributes][:claimInformation][:disabilities].any? do |disability|
          disability[:isRelatedToToxicExposure] == true
        end
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] =
          has_conditions ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:claimInformation][:disabilities]&.map do |disability|
          disability.delete(:isRelatedToToxicExposure)
        end
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] =
          has_conditions == true ? 'YES' : 'NO'

        @pdf_data
      end

      def treatment_centers
        @pdf_data[:data][:attributes][:claimInformation].merge!(
          treatments: []
        )
        if @auto_claim&.dig('treatments').present?
          treatments = get_treatments

          treatment_details = treatments.map(&:deep_symbolize_keys)
          @pdf_data[:data][:attributes][:claimInformation][:treatments] = treatment_details
        end
        @pdf_data[:data][:attributes].delete(:treatments)

        @pdf_data
      end

      def get_treatments
        @auto_claim['treatments'].map do |tx|
          center = "#{tx['center']['name']}, #{tx['center']['city']}, #{tx['center']['state']}"
          name = tx['treatedDisabilityNames'].join(', ')
          details = "#{name} - #{center}"
          tx['treatmentDetails'] = details
          tx['dateOfTreatment'] = convert_date_string_my_to_object(tx['beginDate']) if tx['beginDate'].present?
          tx['doNotHaveDate'] = tx['beginDate'].nil?
          tx.delete('center')
          tx.delete('treatedDisabilityNames')
          tx.delete('beginDate')
          tx
        end
      end

      def service_info
        symbolize_service_info
        most_recent_service_period
        array_of_remaining_service_date_objects
        confinements
        national_guard
        service_info_other_names
        fed_activation

        @pdf_data
      end

      def symbolize_service_info
        @pdf_data[:data][:attributes][:serviceInformation].merge!(
          @auto_claim['serviceInformation'].deep_symbolize_keys
        )
        served_in_active_combat_since911 =
          @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911]
        @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911] =
          served_in_active_combat_since911 == true ? 'YES' : 'NO'
        served_in_reserves_or_national_guard =
          @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard]
        @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard] =
          served_in_reserves_or_national_guard == true ? 'YES' : 'NO'

        @pdf_data
      end

      def most_recent_service_period
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
        most_recent_period = @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].max_by do |sp|
          sp[:activeDutyEndDate]
        end
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
          start: convert_date_string_mdy_to_object(most_recent_period[:activeDutyBeginDate])
        )
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
          end: convert_date_string_mdy_to_object(most_recent_period[:activeDutyEndDate])
        )
        @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
          most_recent_period[:separationLocationCode]
        @pdf_data[:data][:attributes][:serviceInformation].merge!(branchOfService: {
                                                                    branch: most_recent_period[:serviceBranch]
                                                                  })
        service_component = most_recent_period[:serviceComponent]
        map_component = SERVICE_COMPONENTS[service_component]
        @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = map_component

        @pdf_data
      end

      def array_of_remaining_service_date_objects
        arr = []
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].each do |sp|
          arr.push({ start: convert_date_string_mdy_to_object(sp[:activeDutyBeginDate]),
                     end: convert_date_string_mdy_to_object(sp[:activeDutyEndDate]) })
        end
        sorted = arr.sort_by { |sp| sp[:activeDutyEndDate] }
        sorted.pop if sorted.count > 1
        @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = sorted
        @pdf_data[:data][:attributes][:serviceInformation].delete(:servicePeriods)
        @pdf_data
      end

      def confinements # rubocop:disable Metrics/MethodLength
        return if @pdf_data[:data][:attributes][:serviceInformation][:confinements].blank?

        si = []
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] = { confinementDates: [] }
        @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
          start_date = if confinement[:approximateBeginDate].length == 7
                         convert_date_string_my_to_object(confinement[:approximateBeginDate])
                       else
                         convert_date_string_mdy_to_object(confinement[:approximateBeginDate])
                       end
          end_date = if confinement[:approximateEndDate].length == 7
                       convert_date_string_my_to_object(confinement[:approximateEndDate])
                     else
                       convert_date_string_mdy_to_object(confinement[:approximateEndDate])
                     end
          si.push({
                    start: start_date, end: end_date
                  })
          si
        end
        pow = si.present?
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement][:confinementDates] = si
        @pdf_data[:data][:attributes][:serviceInformation][:confinedAsPrisonerOfWar] = pow ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:serviceInformation].delete(:confinements)

        @pdf_data
      end

      def national_guard # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        si = {}
        reserves = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        si[:servedInReservesOrNationalGuard] = 'YES' if reserves
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)
        reserves_begin_date = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService][:beginDate]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService][:start] =
          convert_date_string_mdy_to_object(reserves_begin_date)
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService].delete(:beginDate)
        reserves_end_date = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService][:endDate]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService][:end] =
          convert_date_string_mdy_to_object(reserves_end_date)
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:obligationTermsOfService].delete(:endDate)

        component = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:component]
        map_component = NATIONAL_GUARD_COMPONENTS[component]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:component] = map_component

        area_code = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhone][:areaCode]
        phone_number = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhone][:phoneNumber]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhoneNumber] =
          area_code + phone_number
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService].delete(:unitPhone)

        receiving_inactive_duty_training_pay =
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:receivingInactiveDutyTrainingPay]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:receivingInactiveDutyTrainingPay] =
          receiving_inactive_duty_training_pay ? 'YES' : 'NO'

        @pdf_data
      end
      # rubocop:enable Layout/LineLength

      def service_info_other_names
        other_names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].present?
        if other_names
          names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].join(', ')
          @pdf_data[:data][:attributes][:serviceInformation][:servedUnderAnotherName] = 'YES'
          @pdf_data[:data][:attributes][:serviceInformation][:alternateNames] = names
        end
      end

      def fed_activation
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation] = {}
        ten = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:title10Activation]
        activation_date = ten[:title10ActivationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:activationDate] =
          convert_date_string_mdy_to_object(activation_date)

        anticipated_sep_date = ten[:anticipatedSeparationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:anticipatedSeparationDate] =
          convert_date_string_mdy_to_object(anticipated_sep_date)
        @pdf_data[:data][:attributes][:serviceInformation][:activatedOnFederalOrders] = 'YES' if activation_date
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService].delete(:title10Activation)

        @pdf_data
      end

      def direct_deposit_information
        @pdf_data[:data][:attributes][:directDepositInformation] = @pdf_data[:data][:attributes][:directDeposit]
        @pdf_data[:data][:attributes].delete(:directDeposit)

        @pdf_data
      end

      def claim_date_and_signature
        name = "#{@target_veteran[:first_name]} #{@target_veteran[:last_name]}"
        claim_date = Date.parse @auto_claim&.dig('claimDate')
        claim_date_mdy = claim_date.strftime('%m-%d-%Y')
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: {
                                               dateSigned: convert_date_string_mdy_to_object(claim_date_mdy),
                                               signature: name
                                             })
        @pdf_data[:data][:attributes].delete(:claimDate)
      end

      def get_service_pay # rubocop:disable Metrics/MethodLength
        @pdf_data[:data][:attributes].merge!(
          servicePay: @auto_claim&.dig('servicePay')&.deep_symbolize_keys
        )
        receiving_military_retired_pay = @pdf_data[:data][:attributes][:servicePay][:receivingMilitaryRetiredPay]
        future_military_retired_pay = @pdf_data[:data][:attributes][:servicePay][:futureMilitaryRetiredPay]
        received_separation_or_severance_pay =
          @pdf_data[:data][:attributes][:servicePay][:receivedSeparationOrSeverancePay]
        @pdf_data[:data][:attributes][:servicePay][:receivingMilitaryRetiredPay] =
          receiving_military_retired_pay ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:servicePay][:futureMilitaryRetiredPay] =
          future_military_retired_pay ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:servicePay][:receivedSeparationOrSeverancePay] =
          received_separation_or_severance_pay ? 'YES' : 'NO'
        if @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay].present?
          branch_of_service = @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay][:branchOfService]
          @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay].delete(:branchOfService)
          @pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay].merge!(
            branchOfService: { branch: branch_of_service }
          )
        end
        if @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay].present?
          branch_of_service = @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:branchOfService]
          @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay].delete(:branchOfService)
          @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay].merge!(
            branchOfService: { branch: branch_of_service }
          )
          date_payment_received =
            @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:datePaymentReceived]
          if date_payment_received.length == 7
            @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:datePaymentReceived] =
              convert_date_string_my_to_object(date_payment_received)
          else
            @pdf_data[:data][:attributes][:servicePay][:separationSeverancePay][:datePaymentReceived] =
              convert_date_string_mdy_to_object(date_payment_received)
          end
        end
        @pdf_data
      end

      def convert_date_string_mdy_to_object(date_string)
        return '' if date_string.blank?

        date = Date.strptime(date_string, '%m-%d-%Y')
        {
          month: date.mon,
          day: date.mday,
          year: date.year
        }
      end

      def convert_date_string_my_to_object(date_string)
        return '' if date_string.blank?

        date = Date.strptime(date_string, '%m-%Y')
        {
          month: date.mon,
          year: date.year
        }
      end
    end
  end
end
