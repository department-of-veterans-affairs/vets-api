# frozen_string_literal: true

require_relative 'lighthouse_military_address_validator'

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
        validate_required_fields!

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

      def service_information
        info = @data[:serviceInformation]
        return if info.blank?

        map_service_periods(info)
        map_federal_activation_to_reserves(info) if info&.dig(:federalActivation).present?
        map_reserves_title_ten(info) if info&.dig(:reservesNationalGuardService, :title10Activation).present?
        map_confinements(info) if info&.dig(:confinements).present?
        map_separation_location(info) if info&.dig(:separationLocationCode).present?
      end

      def map_service_periods(info)
        service_periods = info&.dig(:servicePeriods)
        return if service_periods.blank?

        @fes_claim[:serviceInformation] = {
          servicePeriods: format_service_periods(service_periods)
        }
      end

      def map_federal_activation_to_reserves(info)
        activation_date = info&.dig(:federalActivation, :activationDate)
        separation_date = info&.dig(:federalActivation, :anticipatedSeparationDate)
        terms_of_service = info&.dig(:reservesNationalGuardService, :obligationTermsOfService)

        return if activation_date.blank? && separation_date.blank?

        title_ten = {}
        title_ten[:title10ActivationDate] = activation_date if activation_date.present?
        title_ten[:anticipatedSeparationDate] = separation_date if separation_date.present?

        begin_date = terms_of_service&.dig(:beginDate)
        end_date = terms_of_service&.dig(:endDate)

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService] = {
          obligationTermOfServiceFromDate: begin_date,
          obligationTermOfServiceToDate: end_date,
          title10Activation: title_ten
        }.compact_blank
      end

      def map_reserves_title_ten(info)
        # This handles reserves with existing title10Activation but no federal activation
        reserves_info = info[:reservesNationalGuardService]
        return if reserves_info.blank?

        terms_of_service = reserves_info[:obligationTermsOfService]
        title_ten_info = reserves_info[:title10Activation]

        return if title_ten_info.blank?

        title_ten = build_title_ten_activation(title_ten_info)

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService] ||= {}
        @fes_claim[:serviceInformation][:reservesNationalGuardService].merge!({
          obligationTermOfServiceFromDate: terms_of_service&.dig(:beginDate),
          obligationTermOfServiceToDate: terms_of_service&.dig(:endDate),
          title10Activation: title_ten
        }.compact_blank)
      end

      def build_title_ten_activation(title_ten_info)
        title_ten = {}
        if title_ten_info[:title10ActivationDate].present?
          title_ten[:title10ActivationDate] = title_ten_info[:title10ActivationDate]
        end
        if title_ten_info[:anticipatedSeparationDate].present?
          title_ten[:anticipatedSeparationDate] = title_ten_info[:anticipatedSeparationDate]
        end
        title_ten
      end

      def map_confinements(info)
        confinements = format_confinements(info&.dig(:confinements))

        if confinements.present?
          @fes_claim[:serviceInformation] ||= {}
          @fes_claim[:serviceInformation].merge!(
            { confinements: }
          )
        end
      end

      def map_separation_location(info)
        separation_code = info[:separationLocationCode]
        return if separation_code.blank?

        @fes_claim[:serviceInformation] ||= {}
        @fes_claim[:serviceInformation][:separationLocationCode] = separation_code
      end

      def current_mailing_address
        if address_is_military?(veteran_mailing_address)
          handle_military_address
        else
          handle_domestic_or_international_address
        end
      end

      def handle_military_address
        addr = veteran_mailing_address || {}

        # Handle both field formats
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])

        formatted_addr = {
          addressLine1: line1,
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

      def handle_domestic_or_international_address
        addr = veteran_mailing_address || {}
        type = addr[:internationalPostalCode].present? ? 'INTERNATIONAL' : 'DOMESTIC'

        # Handle both field formats
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])

        formatted_addr = {
          addressLine1: line1,
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          country: addr[:country] || 'USA',
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: type
        }

        if type == 'INTERNATIONAL'
          formatted_addr[:internationalPostalCode] = addr[:internationalPostalCode]
        else
          formatted_addr[:city] = addr[:city]
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
        # Handle both field formats
        line1 = change_data[:addressLine1] ||
                format_address_line(change_data[:numberAndStreet], change_data[:apartmentOrUnitNumber])

        {
          addressChangeType: change_data[:addressChangeType],
          beginningDate: change_data[:beginningDate] || change_data.dig(:dates, :beginDate),
          endingDate: change_data[:endingDate] || change_data.dig(:dates, :endDate),
          addressLine1: line1,
          addressLine2: change_data[:addressLine2],
          addressLine3: change_data[:addressLine3],
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
            city: change_data[:city],
            state: change_data[:state],
            addressType: 'DOMESTIC'
          )
        end
      end

      def disabilities
        return if @data[:disabilities].blank?

        @fes_claim[:disabilities] = @data[:disabilities].map do |disability|
          transform_disability_values!(disability.deep_dup)
        end
      end

      def transform_disability_values!(disability)
        # Remove nil fields similar to EVSS mapper
        disability.delete(:diagnosticCode) if disability&.dig(:diagnosticCode).nil?
        disability.delete(:classificationCode) if disability&.dig(:classificationCode).nil?

        # Transform approximate date to FES format
        if disability[:approximateDate].present?
          date_info = disability[:approximateDate]
          disability[:approximateBeginDate] = format_approximate_date(date_info)
        end

        # Handle PACT special issue
        check_for_pact_special_issue(disability) if disability[:disabilityActionType] != 'INCREASE'

        # Remove fields not needed for FES
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
            claimantParticipantId: extract_claimant_participant_id,
            veteranParticipantId: extract_veteran_participant_id,
            form526: @fes_claim
          }
        }
      end

      def format_address_line(street, unit)
        # Handle both formats:
        # 1. numberAndStreet + apartmentOrUnitNumber (Claims API format)
        # 2. addressLine1 already combined (test format)
        return street if street.present? && unit.nil?
        return nil if street.blank?

        [street, unit].compact.join(' ')
      end

      def format_service_periods(service_periods)
        # FES doesn't need date reformatting like EVSS does
        service_periods.map do |sp|
          {
            serviceBranch: abbreviate_service_branch(sp[:serviceBranch]),
            activeDutyBeginDate: sp[:activeDutyBeginDate],
            activeDutyEndDate: sp[:activeDutyEndDate]
          }.compact_blank
        end
      end

      def abbreviate_service_branch(branch)
        # Map full service branch names to their abbreviations
        service_branch_abbreviations = {
          'Public Health Service' => 'PHS',
          'Naval Academy' => 'Navy'
        }

        service_branch_abbreviations[branch] || branch
      end

      def format_confinements(confinements)
        # Same as EVSS mapper - rename date fields
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

      def validate_required_fields!
        # Validate participant IDs are present.
        # These fields are being extracted from request headers which may not be present.
        # NOTE: If these are missing, consider implementing BGS lookup using veteran_icn.
        # to retrieve participant IDs as a fallback strategy.
        veteran_pid = extract_veteran_participant_id
        claimant_pid = extract_claimant_participant_id

        if veteran_pid.blank? || veteran_pid == @auto_claim.veteran_icn
          raise ArgumentError, 'Missing veteranParticipantId - auth_headers do not contain valid participant ID'
        end

        if claimant_pid.blank? || claimant_pid == @auto_claim.veteran_icn
          raise ArgumentError, 'Missing claimantParticipantId - auth_headers do not contain valid participant ID'
        end

        # Validate other required fields
        if @data.dig(:serviceInformation, :servicePeriods).blank?
          raise ArgumentError, 'Missing required serviceInformation.servicePeriods'
        end
        raise ArgumentError, 'Missing required disabilities array' if @data[:disabilities].blank?

        raise ArgumentError, 'Missing required veteran mailing address' if veteran_mailing_address.blank?
      end

      def extract_veteran_participant_id
        # Try auth_headers first, then fall back to other sources
        # NOTE: veteran_icn is NOT a valid participant ID and would require BGS lookup
        @auto_claim.auth_headers&.dig('va_eauth_pid') ||
          @auto_claim.auth_headers&.dig('participant_id') ||
          @auto_claim.veteran_icn # fallback, would need BGS lookup to convert
      end

      def extract_claimant_participant_id
        # For dependent claims, use dependent participant ID
        if @auto_claim.auth_headers&.dig('dependent', 'participant_id').present?
          @auto_claim.auth_headers.dig('dependent', 'participant_id')
        else
          # Otherwise, claimant is the veteran
          extract_veteran_participant_id
        end
      end

      # Helper to handle both v1 and v2 form data structures
      def veteran_mailing_address
        # V2 format: veteranIdentification.mailingAddress
        # V1 format: veteran.currentMailingAddress
        @data.dig(:veteranIdentification, :mailingAddress) || @data.dig(:veteran, :currentMailingAddress)
      end
    end
  end
end
