# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper
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
        @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim&.dig('homeless')&.deep_symbolize_keys
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

      def chg_addr_attributes
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim&.dig('changeOfAddress')&.deep_symbolize_keys

        country = @pdf_data[:data][:attributes][:changeOfAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:changeOfAddress][:country] = abbr_country
        begin_date = @pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginDate]
        @pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginningDate] = begin_date
        end_date = @pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate]
        @pdf_data[:data][:attributes][:changeOfAddress][:dates][:endingDate] = end_date
        chg_addr_zip
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:beginDate)
        @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:endDate)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipLastFour)

        @pdf_data
      end

      def chg_addr_zip
        zip = (@auto_claim&.dig('changeOfAddress', 'zipFirstFive') || '') +
              (@auto_claim&.dig('changeOfAddress', 'zipLastFour') || '')
        addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(zip:) if addr
      end

      # rubocop:disable Layout/LineLength
      def toxic_exposure_attributes
        @pdf_data[:data][:attributes].merge!(
          exposureInformation: { toxicExposure: @auto_claim&.dig('toxicExposure')&.deep_symbolize_keys }
        )
        gulf = @pdf_data&.dig(:data, :attributes, :toxicExposure, :gulfWarHazardService).present?
        if gulf
          served_in_gulf_war_hazard_locations =
            @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:servedInGulfWarHazardLocations] =
            served_in_gulf_war_hazard_locations == true ? 'YES' : 'NO'
        end
        herb = @pdf_data&.dig(:data, :attributes, :toxicExposure, :herbicideHazardService).present?
        if herb
          served_in_herbicide_hazard_locations =
            @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations]
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:servedInHerbicideHazardLocations] =
            served_in_herbicide_hazard_locations == true ? 'YES' : 'NO'
        end
        # rubocop:enable Layout/LineLength

        @pdf_data[:data][:attributes].delete(:toxicExposure)

        @pdf_data
      end

      def veteran_info
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim&.dig('veteranIdentification')&.deep_symbolize_keys
        )

        country = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country] = abbr_country

        zip
        @pdf_data[:data][:attributes].delete(:veteranIdentification)

        @pdf_data
      end

      def zip
        zip = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipFirstFive') || '') +
              (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipLastFour') || '')
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

      def transform_disabilities
        d2 = []
        claim_disabilities = @auto_claim&.dig('disabilities')&.map do |disability|
          disability['disability'] = disability['name']
          disability.delete('name')
          disability.delete('classificationCode')
          disability.delete('ratedDisabilityId')
          disability.delete('diagnosticCode')
          disability.delete('disabilityActionType')
          sec_dis = disability['secondaryDisabilities']&.map do |secondary_disability|
            secondary_disability['disability'] = secondary_disability['name']
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
        has_conditions = @pdf_data[:data][:attributes][:claimInformation][:disabilities].any? do |disabiity|
          disabiity[:isRelatedToToxicExposure] == true
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
        @pdf_data
      end

      def get_treatments
        @auto_claim['treatments'].map do |tx|
          center = "#{tx['center']['name']}, #{tx['center']['city']}, #{tx['center']['state']}"
          name = tx['treatedDisabilityNames'].join(', ')
          details = "#{name} - #{center}"
          tx['treatmentDetails'] = details
          tx['dateOfTreatment'] = tx['beginDate']
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

        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:startDate] =
          most_recent_period[:activeDutyBeginDate]
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService][:endDate] =
          most_recent_period[:activeDutyEndDate]
        @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
          most_recent_period[:separationLocationCode]
        @pdf_data[:data][:attributes][:serviceInformation][:branchOfService] = most_recent_period[:serviceBranch]
        @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = most_recent_period[:serviceComponent]

        @pdf_data
      end

      def array_of_remaining_service_date_objects
        arr = []
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].each do |sp|
          arr.push({ startDate: sp[:activeDutyBeginDate], endDate: sp[:activeDutyEndDate] })
        end
        sorted = arr.sort_by { |sp| sp[:activeDutyEndDate] }
        sorted.pop if sorted.count > 1
        @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = sorted
        @pdf_data[:data][:attributes][:serviceInformation].delete(:servicePeriods)
        @pdf_data
      end

      def confinements
        si = []
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] = { confinementDates: [] }
        @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
          start = confinement[:approximateBeginDate]
          end_date = confinement[:approximateEndDate]
          si.push({
                    startDate: start, endDate: end_date
                  })
          si
        end
        pow = si.present?
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement][:confinementDates] = si
        @pdf_data[:data][:attributes][:serviceInformation][:confinedAsPrisonerOfWar] = pow == true ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:serviceInformation].delete(:confinements)

        @pdf_data
      end

      # rubocop:disable Layout/LineLength
      def national_guard
        si = {}
        reserves = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        si[:servedInReservesOrNationalGuard] = 'YES' if reserves
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)

        receiving_inactive_duty_training_pay =
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:receivingInactiveDutyTrainingPay]
        @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:receivingInactiveDutyTrainingPay] =
          receiving_inactive_duty_training_pay == true ? 'YES' : 'NO'

        @pdf_data
      end

      # rubocop:enable Layout/LineLength
      def service_info_other_names
        other_names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].present?
        names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].join(', ')
        @pdf_data[:data][:attributes][:serviceInformation][:servedUnderAnotherName] = 'YES' if other_names
        @pdf_data[:data][:attributes][:serviceInformation][:alternateNames] = names
      end

      def fed_activation
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation] = {}
        ten = @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:title10Activation]
        activation_date = ten[:title10ActivationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:activationDate] = activation_date

        anticipated_sep_date = ten[:anticipatedSeparationDate]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:anticipatedSeparationDate] =
          anticipated_sep_date
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
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: {
                                               dateSigned: @auto_claim&.dig('claimDate'),
                                               signature: name
                                             })
        @pdf_data[:data][:attributes].delete(:claimDate)
      end

      def get_service_pay
        @pdf_data[:data][:attributes].merge!(
          servicePay: @auto_claim&.dig('servicePay')&.deep_symbolize_keys
        )
        receiving_military_retired_pay = @pdf_data[:data][:attributes][:servicePay][:receivingMilitaryRetiredPay]
        @pdf_data[:data][:attributes][:servicePay][:futureMilitaryRetiredPay]
        received_separation_or_severance_pay =
          @pdf_data[:data][:attributes][:servicePay][:receivedSeparationOrSeverancePay]
        @pdf_data[:data][:attributes][:servicePay][:receivingMilitaryRetiredPay] =
          receiving_military_retired_pay == true ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:servicePay][:futureMilitaryRetiredPay] =
          receiving_military_retired_pay == true ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:servicePay][:receivedSeparationOrSeverancePay] =
          received_separation_or_severance_pay == true ? 'YES' : 'NO'
        zip

        @pdf_data
      end
    end
  end
end
