# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilitiyCompensationPdfMapper
      def initialize(auto_claim, pdf_data)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
      end

      def map_claim
        claim_attributes
        chg_addr_attributes
        veteran_info

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim.deep_symbolize_keys
        claim_date

        @pdf_data
      end

      def claim_date
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: { dateSigned: @auto_claim['claimDate'] })
        @pdf_data[:data][:attributes].delete(:claimDate)
        @pdf_data
      end

      # change of address
      def chg_addr_attributes
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim['changeOfAddress'].deep_symbolize_keys

        chg_addr_zip

        @pdf_data
      end

      def veteran_info
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim['veteranIdentification'].deep_symbolize_keys
        )
        zip

        @pdf_data
      end

      def zip
        zip = @auto_claim['veteranIdentification']['mailingAddress']['zipFirstFive'] +
              @auto_claim['veteranIdentification']['mailingAddress']['zipLastFour']
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:)
      end

      def chg_addr_zip
        zip = @auto_claim['changeOfAddress']['zipFirstFive'] +
              @auto_claim['changeOfAddress']['zipLastFour']
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(zip:)
      end
    end
  end
end
