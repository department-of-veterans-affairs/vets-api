# frozen_string_literal: true

require 'claims_api/v2/disability_compensation_shared_service_module'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper # rubocop:disable Metrics/ClassLength
      include DisabilityCompensationSharedServiceModule

      NATIONAL_GUARD_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES'
      }.freeze

      SERVICE_COMPONENTS = {
        'National Guard' => 'NATIONAL_GUARD',
        'Reserves' => 'RESERVES',
        'Active' => 'ACTIVE'
      }.freeze

      DATE_FORMATS = {
        10 => :convert_date_string_to_format_mdy,
        7 => :convert_date_string_to_format_my,
        4 => :convert_date_string_to_format_yyyy
      }.freeze

      BDD_LOWER_LIMIT = 90
      BDD_UPPER_LIMIT = 180

      def initialize(auto_claim, pdf_data, auth_headers, middle_initial, created_at)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
        @auth_headers = auth_headers&.deep_symbolize_keys
        @middle_initial = middle_initial
        @created_at = created_at.strftime('%Y-%m-%d').to_s
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
        deep_compact(@pdf_data[:data][:attributes])

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim&.deep_symbolize_keys
        @pdf_data[:data][:attributes].delete(:claimantCertification)
        claim_date_and_signature
        claim_process_type
        claim_notes

        @pdf_data
      end

      def claim_notes
        if @auto_claim&.dig('claimNotes').present?
          @pdf_data[:data][:attributes][:overflowText] = @auto_claim&.dig('claimNotes')
          @pdf_data[:data][:attributes].delete(:claimNotes)
        end
      end

      def claim_process_type
        if @auto_claim&.dig('claimProcessType') == 'BDD_PROGRAM'
          @pdf_data[:data][:attributes][:claimProcessType] = 'BDD_PROGRAM_CLAIM'
        end

        @pdf_data
      end

      def homeless_attributes
        if @auto_claim&.dig('homeless').present?
          @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim&.dig('homeless')&.deep_symbolize_keys

          homeless_info = @pdf_data&.dig(:data, :attributes, :homelessInformation)
          new_homeless_info = @pdf_data&.dig(:data, :attributes, :homeless)

          homeless_phone_info(homeless_info, new_homeless_info) if homeless_info && new_homeless_info
          if @pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber].blank?
            @pdf_data[:data][:attributes][:homelessInformation].delete(:pointOfContactNumber)
          end
          homeless_at_risk_or_currently
        end
        @pdf_data[:data][:attributes].delete(:homeless)

        @pdf_data
      end

      def homeless_phone_info(homeless_info, new_homeless_info)
        poc_phone = new_homeless_info&.dig(:pointOfContactNumber, :telephone)
        poc_international = new_homeless_info&.dig(:pointOfContactNumber, :internationalTelephone)

        phone = convert_phone(poc_phone) if poc_phone.present?
        international = convert_phone(poc_international) if poc_international.present?

        homeless_info[:pointOfContactNumber][:telephone] = phone unless phone.nil?
        homeless_info[:pointOfContactNumber]&.delete(:telephone) if phone.nil?
        homeless_info[:pointOfContactNumber][:internationalTelephone] = international unless international.nil?
        homeless_info[:pointOfContactNumber]&.delete(:internationalTelephone) if international.nil?
      end

      def homeless_at_risk_or_currently
        currently = @auto_claim&.dig('homeless', 'isCurrentlyHomeless')&.to_s
        if currently == 'true'
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: 'YES')
        elsif currently == 'false'
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: 'NO')
        end

        at_risk = @auto_claim&.dig('homeless', 'isAtRiskOfBecomingHomeless').to_s
        if at_risk == 'true'
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: 'YES')
        elsif at_risk == 'false'
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: 'NO')
        end

        @pdf_data[:data][:attributes][:homelessInformation]&.delete(:isCurrentlyHomeless)
        @pdf_data[:data][:attributes][:homelessInformation]&.delete(:isAtRiskOfBecomingHomeless)

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

        chg_addr_dates if @pdf_data[:data][:attributes][:changeOfAddress][:dates].present?

        change_addr = @pdf_data[:data][:attributes][:changeOfAddress]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet] =
          concatenate_address(change_addr[:addressLine1], change_addr[:addressLine2], change_addr[:addressLine3])

        city = @pdf_data[:data][:attributes][:changeOfAddress][:city]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city] = city
        state = @pdf_data[:data][:attributes][:changeOfAddress][:state]
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state] = state
        chg_addr_zip

        @pdf_data[:data][:attributes][:changeOfAddress].delete(:dates)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine1)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine2)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:addressLine3)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:numberAndStreet)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:apartmentOrUnitNumber)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:city)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:state)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:zipLastFour)
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:country)

        @pdf_data
      end

      def chg_addr_dates
        if @pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginDate].present?
          begin_date = @pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginDate]

          @pdf_data[:data][:attributes][:changeOfAddress].merge!(
            effectiveDates: {
              start:
              make_date_object(begin_date, begin_date.length)
            }
          )

          @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:beginDate)
        end
        if @pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate].present?
          end_date = @pdf_data[:data][:attributes][:changeOfAddress][:dates][:endDate]
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end] =
            make_date_object(end_date, end_date.length)

          @pdf_data[:data][:attributes][:changeOfAddress][:dates].delete(:endDate)
        end
      end

      def chg_addr_zip
        zip_first_five = @auto_claim&.dig('changeOfAddress', 'zipFirstFive') || ''
        zip_last_four = @auto_claim&.dig('changeOfAddress', 'zipLastFour') || ''
        international_zip = @auto_claim&.dig('changeOfAddress', 'internationalPostalCode')
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              elsif international_zip.present?
                international_zip
              else
                zip_first_five
              end
        addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress].merge!(zip:) if addr
        @pdf_data[:data][:attributes][:changeOfAddress].delete(:internationalPostalCode)
      end

      def toxic_exposure_attributes
        toxic = @auto_claim&.dig('toxicExposure').present?
        if toxic
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
      end

      # rubocop:disable Layout/LineLength
      def gulfwar_hazard
        gulf = @pdf_data&.dig(:data, :attributes, :toxicExposure, :gulfWarHazardService)
        return if gulf.blank?

        if gulf[:serviceDates].present?
          gulfwar_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:beginDate]
          if gulfwar_service_dates_begin.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:start] =
              make_date_object(gulfwar_service_dates_begin, gulfwar_service_dates_begin.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:beginDate)
          gulfwar_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:gulfWarHazardService][:serviceDates][:endDate]
          if gulfwar_service_dates_end.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates][:end] =
              make_date_object(gulfwar_service_dates_end, gulfwar_service_dates_end.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:gulfWarHazardService][:serviceDates].delete(:endDate)
        end
      end

      def herbicide_hazard
        herb = @pdf_data&.dig(:data, :attributes, :toxicExposure, :herbicideHazardService)
        return if herb.blank?

        if herb[:serviceDates].present?
          herbicide_service_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:beginDate]
          if herbicide_service_dates_begin.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:start] =
              make_date_object(herbicide_service_dates_begin, herbicide_service_dates_begin.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:beginDate)
          herbicide_service_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:herbicideHazardService][:serviceDates][:endDate]
          if herbicide_service_dates_end.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates][:end] =
              make_date_object(herbicide_service_dates_end, herbicide_service_dates_end.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService][:serviceDates].delete(:endDate)
        end
      end

      def additional_exposures
        add = @pdf_data&.dig(:data, :attributes, :toxicExposure, :additionalHazardExposures)
        return if add.blank?

        if add[:exposureDates].present?
          additional_exposure_dates_begin = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:beginDate]
          if additional_exposure_dates_begin.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:start] =
              make_date_object(additional_exposure_dates_begin, additional_exposure_dates_begin.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:beginDate)
          additional_exposure_dates_end = @pdf_data[:data][:attributes][:toxicExposure][:additionalHazardExposures][:exposureDates][:endDate]
          if additional_exposure_dates_end.present?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates][:end] =
              make_date_object(additional_exposure_dates_end, additional_exposure_dates_end.length)
          end
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures][:exposureDates].delete(:endDate)
        end
      end

      def multiple_exposures # rubocop:disable Metrics/MethodLength
        if @pdf_data&.dig(:data, :attributes, :toxicExposure, :multipleExposures).present?
          @pdf_data[:data][:attributes][:toxicExposure][:multipleExposures].each_with_index do |exp, index|
            if exp[:exposureDates].present?
              multiple_service_dates_begin = exp[:exposureDates][:beginDate]
              if multiple_service_dates_begin.present?
                @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:start] =
                  make_date_object(multiple_service_dates_begin, multiple_service_dates_begin.length)
              end
              @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:beginDate)

              multiple_service_dates_end = exp[:exposureDates][:endDate]
              if multiple_service_dates_end.present?
                @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates][:end] =
                  make_date_object(multiple_service_dates_end, multiple_service_dates_end.length)
              end
              @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index][:exposureDates].delete(:endDate)
            else
              @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][index].delete(:exposureDates)
            end
            clean_up_exposure(exp, index)
          end
          if @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures].empty?
            @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure].delete(:multipleExposures)
          end
        end
        @pdf_data
      end

      def clean_up_exposure(exp, idx)
        deep_compact(exp)

        if @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][idx][:exposureDates].empty?
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures][idx].delete(:exposureDates)
        end

        if exp.empty?
          @pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:multipleExposures].delete_at(idx)
        end
      end

      def deep_compact(hash)
        hash.each_value { |value| deep_compact(value) if value.is_a? Hash }
        hash.select! { |_, value| exists?(value) }
        hash
      end

      def exists?(value)
        if [true, false].include?(value)
          true
        elsif value.is_a?(String) || value.is_a?(Hash)
          !value.empty?
        else
          !value.nil?
        end
      end

      def veteran_info # rubocop:disable Metrics/MethodLength
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim&.dig('veteranIdentification')&.deep_symbolize_keys
        )
        @pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber] = @auth_headers[:va_eauth_birlsfilenumber]
        vet_number = @pdf_data[:data][:attributes][:identificationInformation][:veteranNumber].present?
        if vet_number
          phone = convert_phone(@pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:telephone])
          international_telephone =
            convert_phone(@pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:internationalTelephone])
        end
        if phone
          @pdf_data[:data][:attributes][:identificationInformation].merge!(
            phoneNumber: { telephone: phone }
          )
        end
        if international_telephone
          if @pdf_data[:data][:attributes][:identificationInformation][:phoneNumber].present?
            @pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:internationalTelephone] =
              international_telephone
          else
            @pdf_data[:data][:attributes][:identificationInformation].merge!(
              phoneNumber: { internationalTelephone: international_telephone }
            )
          end
        end
        additional_identification_info

        @pdf_data[:data][:attributes][:identificationInformation].delete(:veteranNumber)

        mailing_address

        @pdf_data[:data][:attributes].delete(:veteranIdentification)

        date_of_release

        @pdf_data
      end

      def mailing_address
        mailing_addr = @auto_claim&.dig('veteranIdentification', 'mailingAddress')
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:numberAndStreet] =
          concatenate_address(mailing_addr['addressLine1'], mailing_addr['addressLine2'], mailing_addr['addressLine3'])
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine1)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine2)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:addressLine3)

        country = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        abbr_country = country == 'USA' ? 'US' : country
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country] = abbr_country
        zip
      end

      def concatenate_address(address_line_one, address_line_two, address_line_three)
        concatted = "#{address_line_one || ''} #{address_line_two || ''} #{address_line_three || ''}"
        concatted.strip
      end

      def zip
        zip_first_five = @auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipFirstFive') || ''
        zip_last_four = @auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipLastFour') || ''
        international_zip = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress, :internationalPostalCode)
        zip = if zip_last_four.present?
                "#{zip_first_five}-#{zip_last_four}"
              elsif international_zip.present?
                international_zip
              else
                zip_first_five
              end
        mailing_addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:) if mailing_addr
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipFirstFive)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:zipLastFour)
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].delete(:internationalPostalCode)

        @pdf_data
      end

      def date_of_release
        if @pdf_data[:data][:attributes][:claimProcessType] == 'BDD_PROGRAM_CLAIM'
          claim_date = Date.parse(@created_at.to_s)
          service_information = @auto_claim['serviceInformation']

          active_dates = service_information['servicePeriods']&.pluck('activeDutyEndDate')
          active_dates << service_information&.dig('federalActivation', 'anticipatedSeparationDate')

          end_or_separation_date = active_dates.compact.find do |a|
            Date.strptime(a, '%Y-%m-%d').between?(claim_date.next_day(BDD_LOWER_LIMIT),
                                                  claim_date.next_day(BDD_UPPER_LIMIT))
          end
          if end_or_separation_date.present?
            @pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty] =
              make_date_object(end_or_separation_date, end_or_separation_date.length)
          end
        end

        @pdf_data
      end

      def disability_attributes
        @pdf_data[:data][:attributes][:claimInformation] = {}
        conditions_related_to_exposure?
        @pdf_data[:data][:attributes][:claimInformation][:disabilities] = transform_disabilities
        @pdf_data[:data][:attributes].delete(:disabilities)
      end

      def transform_disabilities
        [].tap do |disabilities_list|
          @auto_claim&.dig('disabilities')&.map do |disability|
            dis_name = disability['name']
            dis_date = make_date_string_month_first(disability['approximateDate'], disability['approximateDate'].length) if disability['approximateDate'].present?
            exposure = disability['exposureOrEventOrInjury']
            service_relevance = disability['serviceRelevance']

            disabilities_list << build_disability_item(dis_name, dis_date, exposure, service_relevance)
            if disability['secondaryDisabilities'].present?
              disabilities_list << disability['secondaryDisabilities']&.map do |secondary_disability|
                dis_name = "#{secondary_disability['name']} secondary to: #{disability['name']}"
                dis_date = make_date_string_month_first(secondary_disability['approximateDate'], secondary_disability['approximateDate'].length) if secondary_disability['approximateDate'].present?
                exposure = disability['exposureOrEventOrInjury']
                service_relevance = secondary_disability['serviceRelevance']
                build_disability_item(dis_name, dis_date, exposure, service_relevance)
              end
            end
          end
        end.flatten
      end

      def build_disability_item(disability, approximate_date, exposure, service_relevance)
        { disability:, approximateDate: approximate_date, exposureOrEventOrInjury: exposure, serviceRelevance: service_relevance }.compact
      end

      def conditions_related_to_exposure?
        # If any disability is included in the request with 'isRelatedToToxicExposure' set to true,
        # set exposureInformation.hasConditionsRelatedToToxicExposures to true.
        if @pdf_data[:data][:attributes][:exposureInformation].nil?
          @pdf_data[:data][:attributes][:exposureInformation] = { hasConditionsRelatedToToxicExposures: nil }
        end
        has_conditions = @auto_claim['disabilities'].any? do |disability|
          disability['isRelatedToToxicExposure'] == true
        end
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] =
          has_conditions ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:claimInformation][:disabilities]&.map do |disability|
          disability.delete(:isRelatedToToxicExposure)
        end

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
          if tx['center'].present?
            center_data = tx['center'].transform_keys(&:to_sym)
            center = center_data.values_at(:name, :city, :state).compact.map(&:presence).compact.join(', ')
          end
          names = tx['treatedDisabilityNames']
          name = names.join(', ') if names.present?
          tx['treatmentDetails'] = [name, center].compact.join(' - ')
          tx['dateOfTreatment'] = make_date_object(tx['beginDate'], tx['beginDate'].length) if tx['beginDate'].present?
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
        if @auto_claim.dig('data', 'attributes', 'serviceInformation', 'servedInActiveCombatSince911').present?
          served_in_active_combat_since911 =
            @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911]
          @pdf_data[:data][:attributes][:serviceInformation][:servedInActiveCombatSince911] =
            served_in_active_combat_since911 == true ? 'YES' : 'NO'
        end
        served_in_reserves_or_national_guard =
          @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard]
        if served_in_reserves_or_national_guard.nil?
          @pdf_data[:data][:attributes][:serviceInformation].delete(:servedInReservesOrNationalGuard)
        else
          @pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard] =
            served_in_reserves_or_national_guard == true ? 'YES' : 'NO'
        end

        @pdf_data
      end

      def most_recent_service_period
        @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService] = {}
        most_recent_period = get_most_recent_period
        convert_active_duty_dates(most_recent_period)
        service_component = most_recent_period[:serviceComponent]
        map_component = SERVICE_COMPONENTS[service_component]
        @pdf_data[:data][:attributes][:serviceInformation][:serviceComponent] = map_component

        @pdf_data
      end

      def get_most_recent_period
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].max_by do |sp|
          sp[:activeDutyEndDate].presence || {}
        end
      end

      def convert_active_duty_dates(most_recent_period)
        convert_active_duty_begin_date(most_recent_period)
        if most_recent_period[:activeDutyEndDate].present?
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
            end:
            make_date_object(most_recent_period[:activeDutyEndDate], most_recent_period[:activeDutyEndDate].length)
          )
          location = get_location(most_recent_period[:separationLocationCode])
          if location.present?
            location_description = location[:description]
            @pdf_data[:data][:attributes][:serviceInformation][:placeOfLastOrAnticipatedSeparation] =
              location_description
          end
        end
        @pdf_data[:data][:attributes][:serviceInformation].merge!(branchOfService: {
                                                                    branch: most_recent_period[:serviceBranch]
                                                                  })
        most_recent_period
      end

      def convert_active_duty_begin_date(most_recent_period)
        if most_recent_period[:activeDutyBeginDate].present?
          @pdf_data[:data][:attributes][:serviceInformation][:mostRecentActiveService].merge!(
            start:
            make_date_object(most_recent_period[:activeDutyBeginDate], most_recent_period[:activeDutyBeginDate].length)
          )
        end
      end

      def array_of_remaining_service_date_objects
        arr = []
        @pdf_data[:data][:attributes][:serviceInformation][:servicePeriods].each do |sp|
          next if sp[:activeDutyBeginDate].nil? || sp[:activeDutyEndDate].nil?

          arr.push({ start:
            make_date_object(sp[:activeDutyBeginDate], sp[:activeDutyBeginDate].length),
                     end:
                     make_date_object(sp[:activeDutyEndDate], sp[:activeDutyEndDate].length) })
        end
        sorted = arr&.sort_by { |sp| sp[:activeDutyEndDate] }

        if sorted.count > 1
          sorted.pop
          @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = sorted
        else
          @pdf_data[:data][:attributes][:serviceInformation][:additionalPeriodsOfService] = {}
        end

        @pdf_data[:data][:attributes][:serviceInformation].delete(:servicePeriods)
        @pdf_data
      end

      def confinements
        if @pdf_data[:data][:attributes][:serviceInformation][:confinements].blank?
          return @pdf_data[:data][:attributes][:serviceInformation].delete(:confinements)
        end

        si = []
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement] = { confinementDates: [] }
        @pdf_data[:data][:attributes][:serviceInformation][:confinements].map do |confinement|
          start_date =
            make_date_object(confinement[:approximateBeginDate], confinement[:approximateBeginDate]&.length)
          end_date =
            make_date_object(confinement[:approximateEndDate], confinement[:approximateEndDate]&.length)

          info = deep_compact({ start: start_date, end: end_date })
          si.push(info)
          si
        end
        pow = si.present?
        @pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement][:confinementDates] = si
        @pdf_data[:data][:attributes][:serviceInformation][:confinedAsPrisonerOfWar] = pow ? 'YES' : 'NO'
        @pdf_data[:data][:attributes][:serviceInformation].delete(:confinements)

        @pdf_data
      end

      def national_guard # rubocop:disable Metrics/MethodLength
        si = {}
        reserves = @pdf_data&.dig(:data, :attributes, :serviceInformation, :reservesNationalGuardService)
        si[:servedInReservesOrNationalGuard] = 'YES' if reserves
        @pdf_data[:data][:attributes][:serviceInformation].merge!(si)
        if reserves.present?
          if reserves&.dig(:obligationTermsOfService).present?
            reserves_begin_date = reserves[:obligationTermsOfService][:beginDate]
            reserves[:obligationTermsOfService][:start] =
              make_date_object(reserves_begin_date, reserves_begin_date.length)
            reserves[:obligationTermsOfService].delete(:beginDate)
            reserves_end_date = reserves[:obligationTermsOfService][:endDate]
            reserves[:obligationTermsOfService][:end] =
              make_date_object(reserves_end_date, reserves_end_date.length)
            reserves[:obligationTermsOfService].delete(:endDate)
          end
          component = reserves[:component]
          reserves[:component] = NATIONAL_GUARD_COMPONENTS[component]

          area_code = reserves&.dig(:unitPhone, :areaCode)
          phone_number = reserves&.dig(:unitPhone, :phoneNumber)
          phone_number&.delete! '-'
          reserves[:unitPhoneNumber] = (area_code + phone_number) if area_code && phone_number
          reserves.delete(:unitPhone)

          reserves[:receivingInactiveDutyTrainingPay] = handle_yes_no(reserves[:receivingInactiveDutyTrainingPay])
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService] = reserves
        end
      end
      # rubocop:enable Layout/LineLength

      def service_info_other_names
        other_names = @pdf_data[:data][:attributes][:serviceInformation][:alternateNames].present?
        @pdf_data[:data][:attributes][:serviceInformation][:servedUnderAnotherName] = 'YES' if other_names
      end

      def fed_activation
        return if @pdf_data.dig(:data, :attributes, :serviceInformation, :federalActivation).nil?

        ten = @pdf_data[:data][:attributes][:serviceInformation][:federalActivation]
        @pdf_data[:data][:attributes][:serviceInformation][:federalActivation] = {}
        activation_date = ten[:activationDate]
        if activation_date.present?
          @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:activationDate] =
            make_date_object(activation_date, activation_date.length)
        end

        anticipated_sep_date = ten[:anticipatedSeparationDate]
        if anticipated_sep_date.present?
          @pdf_data[:data][:attributes][:serviceInformation][:federalActivation][:anticipatedSeparationDate] =
            make_date_object(anticipated_sep_date, anticipated_sep_date.length)
        end
        @pdf_data[:data][:attributes][:serviceInformation][:activatedOnFederalOrders] = activation_date ? 'YES' : 'NO'
        if @pdf_data&.dig(
          'data', 'attributes', 'serviceInformation', 'reservesNationalGuardService', 'federalActivation'
        ).present?
          @pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService].delete(:federalActivation)
        end
        @pdf_data
      end

      def direct_deposit_information
        @pdf_data[:data][:attributes][:directDepositInformation] = @pdf_data[:data][:attributes][:directDeposit]
        @pdf_data[:data][:attributes].delete(:directDeposit)

        @pdf_data
      end

      def claim_date_and_signature
        first_name = @auth_headers[:va_eauth_firstName]
        last_name = @auth_headers[:va_eauth_lastName]
        name = "#{first_name} #{last_name}"
        date_signed = get_date_signed
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: {
                                               dateSigned: date_signed,
                                               signature: name
                                             })
        @pdf_data[:data][:attributes].delete(:claimDate)
      end

      def get_date_signed
        # generate_pdf allows for an optional claimDate on its schema
        claim_date_value = @pdf_data.dig(:data, :attributes, :claimDate)
        claim_date_obj = make_date_object(claim_date_value, claim_date_value.length) if claim_date_value.present?
        date = make_date_object(@created_at, @created_at.length) if @created_at.present?
        claim_date_obj || date
      end

      def get_service_pay
        @pdf_data[:data][:attributes].merge!(
          servicePay: @auto_claim&.dig('servicePay')&.deep_symbolize_keys
        )
        service_pay = @pdf_data&.dig(:data, :attributes, :servicePay)
        handle_service_pay if service_pay.present?
        handle_military_retired_pay if service_pay&.dig(:militaryRetiredPay).present?
        handle_seperation_severance_pay if service_pay&.dig(:separationSeverancePay).present?

        @pdf_data
      end

      def get_location(location_code)
        retrieve_separation_locations.detect do |location|
          location_code == location[:id].to_s
        end
      end

      def handle_yes_no(pay)
        pay ? 'YES' : 'NO'
      end

      def handle_branch(branch)
        { branch: }
      end

      def handle_service_pay
        service_pay = @pdf_data&.dig(:data, :attributes, :servicePay)
        service_pay[:receivingMilitaryRetiredPay] = handle_yes_no(service_pay[:receivingMilitaryRetiredPay])
        service_pay[:futureMilitaryRetiredPay] = handle_yes_no(service_pay[:futureMilitaryRetiredPay])
        service_pay[:receivedSeparationOrSeverancePay] = handle_yes_no(service_pay[:receivedSeparationOrSeverancePay])
      end

      def handle_military_retired_pay
        military_retired_pay = @pdf_data&.dig(:data, :attributes, :servicePay, :militaryRetiredPay)
        branch_of_service = military_retired_pay[:branchOfService]
        military_retired_pay[:branchOfService] = handle_branch(branch_of_service) unless branch_of_service.nil?
      end

      def handle_seperation_severance_pay
        seperation_severance_pay = @pdf_data&.dig(:data, :attributes, :servicePay, :separationSeverancePay)
        branch_of_service = @pdf_data&.dig(:data, :attributes, :servicePay, :separationSeverancePay, :branchOfService)
        seperation_severance_pay[:branchOfService] = handle_branch(branch_of_service)
        date = seperation_severance_pay[:datePaymentReceived]
        if date.present?
          seperation_severance_pay[:datePaymentReceived] =
            make_date_object(date, date.length)
        end
      end

      def convert_date_to_object(date_string)
        return '' if date_string.blank?

        date_format = DATE_FORMATS[date_string.length]
        send(date_format, date_string) if date_format
      end

      def convert_date_string_to_format_mdy(date_string)
        arr = date_string.split('-')
        {
          month: arr[0].to_s,
          day: arr[1].to_s,
          year: arr[2].to_s
        }
      end

      def convert_date_string_to_format_my(date_string)
        arr = date_string.split('-')
        {
          month: arr[0].to_s,
          year: arr[1].to_s
        }
      end

      def convert_phone(phone)
        phone&.gsub!(/[^0-9]/, '')
        return nil if phone.nil? || (phone.length < 10)

        return "#{phone[0..2]}-#{phone[3..5]}-#{phone[6..9]}" if phone.length == 10

        "#{phone[0..1]}-#{phone[2..3]}-#{phone[4..7]}-#{phone[8..11]}" if phone.length > 10
      end

      def convert_date_string_to_format_yyyy(date_string)
        date = Date.strptime(date_string, '%Y')
        {
          year: date.year
        }
      end

      def additional_identification_info
        name = {
          lastName: @auth_headers[:va_eauth_lastName],
          firstName: @auth_headers[:va_eauth_firstName],
          middleInitial: @middle_initial
        }
        birth_date_data = @auth_headers[:va_eauth_birthdate]
        if birth_date_data
          birth_date =
            {
              month: birth_date_data[5..6].to_s,
              day: birth_date_data[8..9].to_s,
              year: birth_date_data[0..3].to_s
            }
        end
        ssn = @auth_headers[:va_eauth_pnid]
        formated_ssn = "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
        @pdf_data[:data][:attributes][:identificationInformation][:name] = name
        @pdf_data[:data][:attributes][:identificationInformation][:ssn] = formated_ssn
        @pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth] = birth_date
        @pdf_data
      end

      def regex_date_conversion(date)
        if date.present?
          date_match = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength
          date_match&.values_at(:year, :month, :day)
        end
      end

      def make_date_object(date, date_length)
        year, month, day = regex_date_conversion(date)
        return if year.nil? || date_length.nil?

        if date_length == 4
          { year: }
        elsif date_length == 7
          { month:, year: }
        else
          { year:, month:, day: }
        end
      end

      def make_date_string_month_first(date, date_length)
        year, month, day = regex_date_conversion(date)
        return if year.nil? || date_length.nil?

        if date_length == 4
          year.to_s
        elsif date_length == 7
          "#{month}/#{year}"
        else
          "#{month}/#{day}/#{year}"
        end
      end
    end
  end
end
