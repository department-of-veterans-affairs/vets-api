# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilitiyCompensationPdfMapper
      def initialize(auto_claim, pdf_data)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
      end

      def map_claim
        claim_date
        claim_process_type
        @pdf_data
      end

      def claim_date
        @pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned] =
          @auto_claim['claimDate']
        @pdf_data
      end

      def claim_process_type
        @pdf_data[:data][:attributes][:claimProcessType] = @auto_claim['claimProcessType']
        @pdf_data
      end
    end
  end
end
