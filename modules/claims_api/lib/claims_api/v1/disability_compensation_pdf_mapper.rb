# frozen_string_literal: true

module ClaimsApi
  module V1
    class DisabilityCompensationPdfMapper
      def initialize(auto_claim, pdf_data)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
      end

      def map_claim
        section_0_claim_attributes

        @pdf_data
      end

      private

      def section_0_claim_attributes
        claim_process_type = @auto_claim['standardClaim'] ? 'STANDARD_CLAIM_PROCESS' : 'FDC_PROGRAM'
        claim_process_type = 'BDD_PROGRAM' if any_service_end_dates_in_future_window?

        @pdf_data[:data][:attributes][:claimProcessType] = claim_process_type
      end

      def any_service_end_dates_in_future_window?
        @auto_claim['serviceInformation']['servicePeriods'].each do |sp|
          end_date = sp['activeDutyEndDate'].to_date
          return true if end_date >= 90.days.from_now && end_date <= 180.days.from_now
        end

        false
      end
    end
  end
end
