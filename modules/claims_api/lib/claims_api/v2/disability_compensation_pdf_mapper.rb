# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationPdfMapper
      def initialize(auto_claim, pdf_data)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
      end

      def map_claim
        claim_attributes
        toxic_exposure_attributes
        homeless_attributes
        chg_addr_attributes
        veteran_info
        disability_attributes

        treatment_centers

        @pdf_data
      end

      def claim_attributes
        @pdf_data[:data][:attributes] = @auto_claim&.deep_symbolize_keys
        claim_date
        veteran_info

        @pdf_data
      end

      def claim_date
        @pdf_data[:data][:attributes].merge!(claimCertificationAndSignature: {
                                               dateSigned: @auto_claim&.dig('claimDate')
                                             })
        @pdf_data[:data][:attributes].delete(:claimDate)

        @pdf_data
      end

      def homeless_attributes
        @pdf_data[:data][:attributes][:homelessInformation] = @auto_claim&.dig('homeless')&.deep_symbolize_keys
        @pdf_data[:data][:attributes].delete(:homeless)

        homeless_at_risk_or_currently

        @pdf_data
      end

      def homeless_at_risk_or_currently
        at_risk = @auto_claim&.dig('homeless', 'riskOfBecomingHomeless', 'otherDescription').present?
        currently = @auto_claim&.dig('homeless', 'pointOfContact').present?

        if currently && !at_risk
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouCurrentlyHomeless: true)
        else
          homeless = @pdf_data[:data][:attributes][:homelessInformation].present?
          @pdf_data[:data][:attributes][:homelessInformation].merge!(areYouAtRiskOfBecomingHomeless: true) if homeless
        end

        @pdf_data
      end

      def chg_addr_attributes
        @pdf_data[:data][:attributes][:changeOfAddress] =
          @auto_claim&.dig('changeOfAddress')&.deep_symbolize_keys

        chg_addr_zip

        @pdf_data
      end

      def chg_addr_zip
        zip = (@auto_claim&.dig('changeOfAddress', 'zipFirstFive') || '') +
              (@auto_claim&.dig('changeOfAddress', 'zipLastFour') || '')
        addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:changeOfAddress].merge!(zip:) if addr
      end

      def toxic_exposure_attributes
        @pdf_data[:data][:attributes].merge!(
          exposureInformation: { toxicExposure: @auto_claim&.dig('toxicExposure')&.deep_symbolize_keys }
        )
        @pdf_data[:data][:attributes].delete(:toxicExposure)

        @pdf_data
      end

      def veteran_info
        @pdf_data[:data][:attributes].merge!(
          identificationInformation: @auto_claim&.dig('veteranIdentification')&.deep_symbolize_keys
        )
        zip

        @pdf_data
      end

      def zip
        zip = (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipFirstFive') || '') +
              (@auto_claim&.dig('veteranIdentification', 'mailingAddress', 'zipLastFour') || '')
        mailing_addr = @pdf_data&.dig(:data, :attributes, :identificationInformation, :mailingAddress).present?
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress].merge!(zip:) if mailing_addr
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
          sec_dis = disability['secondaryDisabilities'].map do |secondary_disability|
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
        @pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures] = has_conditions

        @pdf_data
      end

      def treatment_centers
        @pdf_data[:data][:attributes][:claimInformation].merge!(
          treatments: []
        )
        treatments = get_treatments

        treatment_details = treatments.map(&:deep_symbolize_keys)
        @pdf_data[:data][:attributes][:claimInformation][:treatments] = treatment_details

        @pdf_data
      end

      def get_treatments
        @auto_claim['treatments'].map do |tx|
          center = "#{tx['center']['name']}, #{tx['center']['city']}, #{tx['center']['state']}"
          name = tx['treatedDisabilityNames'].join(', ')
          details = "#{name} - #{center}"
          tx['treatmentDetails'] = details
          tx['dateOfTreatment'] = tx['startDate']
          tx['doNotHaveDate'] = tx['startDate'].nil?
          tx.delete('center')
          tx.delete('treatedDisabilityName')
          tx.delete('startDate')
          tx
        end
      end
    end
  end
end
