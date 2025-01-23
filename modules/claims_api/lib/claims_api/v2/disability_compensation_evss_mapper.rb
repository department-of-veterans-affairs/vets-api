# frozen_string_literal: true

require_relative 'lighthouse_military_address_validator'

module ClaimsApi
  module V2
    class DisabilityCompensationEvssMapper
      include LighthouseMilitaryAddressValidator

      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @evss_claim = {}
      end

      def map_claim
        claim_attributes
        claim_meta

        # must set to true by default so the EVSS Docker Container
        # does not submit a duplicate PDF
        @evss_claim[:autoCestPDFGenerationDisabled] = true
        { form526: @evss_claim }
      end

      private

      def claim_attributes
        service_information
        current_mailing_address
        disabilities
        standard_claim
        claim_process_type
        veteran_meta
      end

      def service_information
        info = @data[:serviceInformation]

        map_service_periods(info)
        map_federal_activation_to_reserves(info) if info&.dig(:federalActivation).present?
        map_reserves_title_ten(info) if info&.dig(:reservesNationalGuardService, :title10Activation).present?
        map_confinements(info) if info&.dig(:confinements).present?
      end

      def map_service_periods(info)
        service_periods = format_service_periods(info&.dig(:servicePeriods))

        @evss_claim[:serviceInformation] = {
          servicePeriods: service_periods
        }
      end

      def map_federal_activation_to_reserves(info)
        activation_date = info&.dig(:federalActivation, :activationDate)
        separation_date = info&.dig(:federalActivation, :anticipatedSeparationDate)
        terms_of_service = info&.dig(:reservesNationalGuardService, :obligationTermsOfService)
        unit_name = info&.dig(:reservesNationalGuardService, :unitName)

        return if activation_date.blank? && separation_date.blank?

        title_ten = {}
        title_ten[:title10ActivationDate] = activation_date if activation_date.present?
        title_ten[:anticipatedSeparationDate] = separation_date if separation_date.present?

        begin_date = terms_of_service&.dig(:beginDate)
        end_date = terms_of_service&.dig(:endDate)

        @evss_claim[:serviceInformation][:reservesNationalGuardService] = {
          unitName: unit_name,
          obligationTermOfServiceFromDate: begin_date,
          obligationTermOfServiceToDate: end_date,
          title10Activation: title_ten
        }
      end

      def map_confinements(info)
        confinements = format_confinements(info&.dig(:confinements))

        if confinements.present?
          @evss_claim[:serviceInformation].merge!(
            { confinements: }
          )
        end
      end

      def current_mailing_address
        if address_is_military?(@data.dig(:veteranIdentification, :mailingAddress))
          handle_military_address
        else
          handle_domestic_or_international_address
        end
      end

      def handle_military_address
        addr = @data.dig(:veteranIdentification, :mailingAddress) || {}
        type = 'MILITARY'
        addr[:militaryPostOfficeTypeCode] = military_city(addr)
        addr[:militaryStateCode] = military_state(addr)

        addr.delete(:city)
        addr.delete(:state)

        @evss_claim[:veteran] ||= {}
        @evss_claim[:veteran][:currentMailingAddress] = addr.compact_blank
        @evss_claim[:veteran][:currentMailingAddress].merge!({ type: })
        @evss_claim[:veteran][:currentMailingAddress].except!(:numberAndStreet, :apartmentOrUnitNumber)
      end

      def handle_domestic_or_international_address
        addr = @data.dig(:veteranIdentification, :mailingAddress) || {}
        type = addr[:internationalPostalCode].present? ? 'INTERNATIONAL' : 'DOMESTIC'
        @evss_claim[:veteran] ||= {}
        @evss_claim[:veteran][:currentMailingAddress] = addr.compact_blank
        @evss_claim[:veteran][:currentMailingAddress].merge!({ type: })
        @evss_claim[:veteran][:currentMailingAddress].except!(:numberAndStreet, :apartmentOrUnitNumber)
      end

      def disabilities
        @evss_claim[:disabilities] = @data[:disabilities]&.map { |disability| transform_disability_values!(disability) }
      end

      def transform_disability_values!(disability)
        disability.delete(:diagnosticCode) if disability&.dig(:diagnosticCode).nil?
        disability.delete(:serviceRelevance) if disability&.dig(:serviceRelevance).blank?
        disability.delete(:classificationCode) if disability&.dig(:classificationCode).nil? # blank is ok

        if disability&.dig(:secondaryDisabilities).present?
          disability[:secondaryDisabilities] = disability[:secondaryDisabilities]&.map do |secondary|
            secondary.delete(:classificationCode) if secondary&.dig(:classificationCode).nil? # blank is ok

            secondary.except(:exposureOrEventOrInjury, :approximateDate)
          end
        end
        check_for_pact_special_issue(disability) if disability[:disabilityActionType] != 'INCREASE'

        disability.except(:approximateDate, :isRelatedToToxicExposure)
      end

      def check_for_pact_special_issue(disability)
        related_to_toxic_exposure = disability[:isRelatedToToxicExposure]
        if related_to_toxic_exposure
          disability[:specialIssues] ||= []
          disability[:specialIssues] << 'PACT'
        end
      end

      def standard_claim
        @evss_claim[:standardClaim] = @data[:claimProcessType] == 'STANDARD_CLAIM_PROCESS'
      end

      def claim_process_type
        @evss_claim[:claimProcessType] = 'BDD_PROGRAM_CLAIM' if @data[:claimProcessType] == 'BDD_PROGRAM'
      end

      def claim_meta
        @evss_claim[:applicationExpirationDate] = Time.zone.today + 1.year
        @evss_claim[:claimantCertification] = @data[:claimantCertification]
        @evss_claim[:claimSubmissionSource] = 'VA.gov'
      end

      def veteran_meta
        @evss_claim[:veteran] ||= {}
        # EVSS Docker needs currentlyVAEmployee, 526 schema uses currentVaEmployee
        @evss_claim[:veteran][:currentlyVAEmployee] = @data.dig(:veteranIdentification, :currentVaEmployee)
        email_address = @data.dig(:veteranIdentification, :emailAddress, :email)
        @evss_claim[:veteran][:emailAddress] = email_address unless email_address.nil?
      end

      # Convert 12-05-1984 to 1984-12-05 for Docker container
      def format_service_periods(service_periods)
        service_periods.each do |sp|
          next if sp[:activeDutyBeginDate].nil?

          begin_year = Date.strptime(sp[:activeDutyBeginDate], '%Y-%m-%d')
          sp[:activeDutyBeginDate] = begin_year.strftime('%Y-%m-%d')
          next if sp[:activeDutyEndDate].nil?

          end_year = Date.strptime(sp[:activeDutyEndDate], '%Y-%m-%d')
          sp[:activeDutyEndDate] = end_year.strftime('%Y-%m-%d')
        end
      end

      def format_confinements(confinements)
        confinements.each do |confinement|
          begin_date = confinement[:approximateBeginDate]
          end_date = confinement[:approximateEndDate]
          confinement.delete(:approximateBeginDate)
          confinement.delete(:approximateEndDate)
          confinement.merge!(
            { confinementBeginDate: begin_date,
              confinementEndDate: end_date }
          )
        end
      end
    end
  end
end
