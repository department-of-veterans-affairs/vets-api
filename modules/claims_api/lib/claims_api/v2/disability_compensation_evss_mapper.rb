# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationEvssMapper
      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @evss_claim = {}
      end

      def map_claim
        claim_attributes
        claim_meta

        { form526: @evss_claim }
      end

      private

      def claim_attributes
        service_information
        current_mailing_address
        direct_deposit
        disabilities
        standard_claim
        veteran_meta
      end

      def current_mailing_address
        addr = @data.dig(:veteranIdentification, :mailingAddress) || {}
        @evss_claim[:veteran] ||= {}
        @evss_claim[:veteran][:currentMailingAddress] = addr
        @evss_claim[:veteran][:currentMailingAddress].merge!({
                                                               addressLine1: addr[:numberAndStreet],
                                                               addressLines2: addr[:apartmentOrUnitNumber],
                                                               type: 'DOMESTIC'
                                                             })
        @evss_claim[:veteran][:currentMailingAddress].except!(:numberAndStreet, :apartmentOrUnitNumber)
      end

      def direct_deposit
        return if @data[:directDeposit].empty?

        @evss_claim[:directDeposit] = @data[:directDeposit]
        @evss_claim[:directDeposit][:bankName] = @data[:directDeposit][:financialInstitutionName]
        @evss_claim[:directDeposit].except!(:financialInstitutionName, :noAccount)
      end

      def disabilities
        @evss_claim[:disabilities] = @data[:disabilities].map do |disability|
          disability[:approximateBeginDate] = map_date_to_obj disability[:approximateDate]
          disability[:secondaryDisabilities] = disability[:secondaryDisabilities].map do |secondary|
            secondary[:approximateBeginDate] = map_date_to_obj secondary[:approximateDate]
            secondary.except(:exposureOrEventOrInjury, :approximateDate)
          end

          disability.except(:approximateDate, :isRelatedToToxicExposure)
        end
      end

      def service_information
        info = @data[:serviceInformation]
        @evss_claim[:serviceInformation] = {
          servicePeriods: info[:servicePeriods],
          reservesNationalGuardService: {
            obligationTermOfServiceFromDate: info[:reservesNationalGuardService][:obligationTermsOfService][:startDate],
            obligationTermOfServiceToDate: info[:reservesNationalGuardService][:obligationTermsOfService][:endDate],
            unitName: info[:reservesNationalGuardService][:unitName]
          }
        }
      end

      def standard_claim
        @evss_claim[:standardClaim] = @data[:claimProcessType] == 'STANDARD_CLAIM_PROCESS'
      end

      def claim_meta
        @evss_claim[:applicationExpirationDate] = Time.zone.today + 1.year
        @evss_claim[:claimantCertification] = @data[:claimantCertification]
        @evss_claim[:submtrApplcnTypeCd] = 'LH-B'
      end

      def veteran_meta
        @evss_claim[:veteran] ||= {}
        @evss_claim[:veteran][:currentlyVAEmployee] = @data.dig(:veteranIdentification, :currentlyVaEmployee)
        @evss_claim[:veteran][:emailAddress] = @data.dig(:veteranIdentification, :emailAddress, :email)
        @evss_claim[:veteran][:fileNumber] = @data.dig(:veteranIdentification, :vaFileNumber)
      end

      def map_date_to_obj(date)
        date = if date.is_a? Date
                 date
               else
                 DateTime.parse(date)
               end
        { year: date.year, month: date.month, day: date.day }
      end
    end
  end
end
