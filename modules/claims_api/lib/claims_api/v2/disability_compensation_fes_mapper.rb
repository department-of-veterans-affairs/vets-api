# frozen_string_literal: true

require_relative '../lighthouse_military_address_validator'

module ClaimsApi
  module V2
    class DisabilityCompensationFesMapper
      include LighthouseMilitaryAddressValidator

      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
      end

      def map_claim
        claim_attributes # builds main data
        claim_meta # adds metadata

        wrap_in_request_structure
      end

      private

      def claim_attributes
        service_information
        current_mailing_address
        change_of_address
        disabilities
        special_circumstances
      end

      # serviceInformation is required via the schema
      def service_information
        info = @data[:serviceInformation]

        map_service_periods(info&.dig(:servicePeriods))
        map_reserves(info[:reservesNationalGuardService]) if info&.dig(:reservesNationalGuardService).present?
        map_federal_activation_to_reserves(info[:federalActivation]) if info&.dig(:federalActivation).present?
        map_confinements(info[:confinements]) if info&.dig(:confinements).present?
        map_separation_location if separation_location_code_present?
      end

      # servicePeriods are required via the schema
      def map_service_periods(service_periods)
        @fes_claim[:serviceInformation] = {
          servicePeriods: format_service_periods(service_periods)
        }.compact_blank
      end

      # Nothing is required via the schema
      def map_reserves(reserves)
        terms_of_service = reserves&.dig(:obligationTermsOfService)
        begin_date = terms_of_service&.dig(:beginDate)
        end_date = terms_of_service&.dig(:endDate)

        return if begin_date.blank? && end_date.blank?

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService] = {
          obligationTermOfServiceFromDate: begin_date,
          obligationTermOfServiceToDate: end_date
        }.compact_blank
      end

      def map_federal_activation_to_reserves(federal_activation)
        activation_date = federal_activation&.dig(:activationDate)
        separation_date = federal_activation&.dig(:anticipatedSeparationDate)

        return if activation_date.blank? && separation_date.blank?

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService][:title10Activation] = {
          title10ActivationDate: activation_date,
          anticipatedSeparationDate: separation_date
        }.compact_blank
      end

      def map_confinements(confinements)
        mapped_confinements = format_confinements(confinements)

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation].merge!(
          { confinements: mapped_confinements }.compact_blank
        )
      end

      def map_separation_location
        @fes_claim[:serviceInformation][:separationLocationCode] = return_separation_location_code
      end

      def current_mailing_address
        mailing_address = @data.dig(:veteranIdentification, :mailingAddress)

        if address_is_military?(mailing_address)
          handle_military_address(mailing_address)
        else
          handle_domestic_or_international_address(mailing_address)
        end
      end

      def handle_military_address(mailing_address)
        addr = mailing_address || {}

        formatted_addr = {
          addressLine1: addr[:addressLine1],
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          country: addr[:country] || 'USA',
          militaryPostOfficeTypeCode: military_city(addr),
          militaryStateCode: military_state(addr),
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: 'MILITARY'
        }.compact_blank

        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:currentMailingAddress] = formatted_addr
      end

      def handle_domestic_or_international_address(mailing_address)
        addr = mailing_address || {}
        type = addr[:internationalPostalCode].present? ? 'INTERNATIONAL' : 'DOMESTIC'

        formatted_addr = {
          addressLine1: addr[:addressLine1],
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          city: addr[:city],
          country: addr[:country] || 'USA',
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: type
        }

        if type == 'INTERNATIONAL'
          formatted_addr[:internationalPostalCode] = addr[:internationalPostalCode]
        else
          formatted_addr[:state] = addr[:state]
        end

        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:currentMailingAddress] = formatted_addr.compact_blank
      end

      def change_of_address
        change_data = @data[:changeOfAddress]
        return if change_data.blank?

        addr = build_change_of_address_base(change_data)
        apply_address_type_fields(addr, change_data)

        addr[:zipFirstFive] = change_data[:zipFirstFive] if change_data[:zipFirstFive].present?
        addr[:zipLastFour] = change_data[:zipLastFour] if change_data[:zipLastFour].present?

        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:changeOfAddress] = addr.compact_blank
      end

      def build_change_of_address_base(change_data)
        {
          addressChangeType: change_data[:typeOfAddressChange],
          beginningDate: change_data[:beginningDate] || change_data.dig(:dates, :beginDate),
          endingDate: change_data[:endingDate] || change_data.dig(:dates, :endDate),
          addressLine1: change_data[:addressLine1],
          addressLine2: change_data[:addressLine2],
          addressLine3: change_data[:addressLine3],
          city: change_data[:city],
          country: change_data[:country] || 'USA'
        }.compact_blank
      end

      def apply_address_type_fields(addr, change_data)
        if address_is_military?(change_data)
          addr.merge!(
            militaryPostOfficeTypeCode: military_city(change_data),
            militaryStateCode: military_state(change_data),
            addressType: 'MILITARY'
          )
        elsif change_data[:internationalPostalCode].present?
          addr.merge!(
            internationalPostalCode: change_data[:internationalPostalCode],
            addressType: 'INTERNATIONAL'
          )
        else
          addr.merge!(
            state: change_data[:state],
            addressType: 'DOMESTIC'
          )
        end
      end

      def disabilities
        @fes_claim[:disabilities] = flatten_and_transform_disabilities(@data[:disabilities])
      end

      def flatten_and_transform_disabilities(disabilities_array)
        disabilities_array.flat_map do |disability|
          primary = disability.deep_dup
          secondaries = primary.delete(:secondaryDisabilities) || []

          list = []
          list << transform_disability_values!(primary) unless primary[:disabilityActionType] == 'NONE'
          transformed_secondaries = secondaries.map do |secondary|
            transform_disability_values!(secondary.deep_dup).merge!(disabilityActionType: 'NEW')
          end
          list.concat(transformed_secondaries)

          list
        end
      end

      def transform_disability_values!(disability)
        disability.delete(:diagnosticCode) if disability&.dig(:diagnosticCode).nil?
        disability.delete(:classificationCode) if disability&.dig(:classificationCode).nil?

        if disability[:approximateDate].present?
          disability[:approximateBeginDate] = format_approximate_date(disability[:approximateDate])
        end

        check_for_pact_special_issue(disability) if disability[:disabilityActionType] != 'INCREASE'

        disability.except(:approximateDate, :isRelatedToToxicExposure, :serviceRelevance,
                          :exposureOrEventOrInjury, :secondaryDisabilities)
      end

      def check_for_pact_special_issue(disability)
        related_to_toxic_exposure = disability[:isRelatedToToxicExposure]
        if related_to_toxic_exposure
          disability[:specialIssues] ||= []
          disability[:specialIssues] << 'PACT' unless disability[:specialIssues].include?('PACT')
        end
      end

      def special_circumstances
        circumstances = @data[:specialCircumstances]
        return if circumstances.blank?

        @fes_claim[:specialCircumstances] = circumstances.map do |circumstance|
          {
            code: circumstance[:code],
            description: circumstance[:name],
            needed: circumstance[:needed] || false
          }.compact_blank
        end
      end

      def claim_meta
        @fes_claim[:claimDate] = @data[:claimDate] || Time.zone.today.to_s
      end

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
            claimantParticipantId: extract_veteran_participant_id,
            veteranParticipantId: extract_veteran_participant_id,
            form526: @fes_claim
          }
        }
      end

      def format_service_periods(service_periods)
        service_periods.map do |sp|
          {
            serviceBranch: sp[:serviceBranch],
            activeDutyBeginDate: sp[:activeDutyBeginDate],
            activeDutyEndDate: sp[:activeDutyEndDate]
          }.compact_blank
        end
      end

      def format_confinements(confinements)
        confinements.map do |confinement|
          {
            confinementBeginDate: confinement[:approximateBeginDate],
            confinementEndDate: confinement[:approximateEndDate]
          }.compact_blank
        end
      end

      def format_approximate_date(date_info)
        return nil if date_info.blank?

        # Handle string date format (e.g., "2018-03-12" or "2015")
        if date_info.is_a?(String)
          parts = date_info.split('-')
          result = { year: parts[0].to_i }
          result[:month] = parts[1].to_i if parts[1].present?
          result[:day] = parts[2].to_i if parts[2].present?
        else
          # Handle object format
          result = { year: date_info[:year] }
          result[:month] = date_info[:month] if date_info[:month].present?
          result[:day] = date_info[:day] if date_info[:day].present?
        end
        result
      end

      def extract_veteran_participant_id
        @auto_claim.auth_headers&.dig('va_eauth_pid') ||
          @auto_claim.auth_headers&.dig('participant_id')
      end

      def return_separation_location_code
        return_most_recent_service_period&.dig(:separationLocationCode)
      end

      def separation_location_code_present?
        return_most_recent_service_period&.dig(:separationLocationCode).present?
      end

      def return_most_recent_service_period
        @data[:serviceInformation][:servicePeriods]&.max_by do |period|
          Date.parse(period[:activeDutyBeginDate])
        end
      end
    end
  end
end
