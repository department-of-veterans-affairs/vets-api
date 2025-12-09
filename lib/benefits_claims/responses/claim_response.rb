# frozen_string_literal: true

require 'vets/model'

module BenefitsClaims
  module Responses
    class ClaimPhaseDates
      include Vets::Model

      attribute :phase_change_date, String
      attribute :phase_type, String
    end

    # Data Transfer Object for standardized claim responses across all providers
    #
    # This DTO defines the canonical claim structure expected by frontend clients
    # (vets-website and VA.gov mobile app). All claim providers must transform
    # their native data formats into this standardized structure.
    #
    # The structure matches the existing Lighthouse format to maintain backward
    # compatibility with frontend consumers.

    class ClaimResponse
      include Vets::Model

      attribute :id, String
      attribute :type, String, default: 'claim'
      attribute :base_end_product_code, String
      attribute :claim_date, String
      attribute :claim_phase_dates, ClaimPhaseDates
      attribute :claim_type, String
      attribute :claim_type_code, String
      attribute :close_date, String
      attribute :decision_letter_sent, Bool
      attribute :development_letter_sent, Bool
      attribute :documents_needed, Bool
      attribute :end_product_code, String
      attribute :evidence_waiver_submitted5103, Bool
      attribute :lighthouse_id, String
      attribute :status, String

      def as_json(_options = {})
        {
          id:,
          type:,
          attributes: attributes_hash
        }
      end

      private

      def attributes_hash
        {
          'baseEndProductCode' => base_end_product_code,
          'claimDate' => claim_date,
          'claimPhaseDates' => serialize_claim_phase_dates,
          'claimType' => claim_type,
          'claimTypeCode' => claim_type_code,
          'closeDate' => close_date,
          'decisionLetterSent' => decision_letter_sent,
          'developmentLetterSent' => development_letter_sent,
          'documentsNeeded' => documents_needed,
          'endProductCode' => end_product_code,
          'evidenceWaiverSubmitted5103' => evidence_waiver_submitted5103,
          'lighthouseId' => lighthouse_id,
          'status' => status
        }.compact
      end

      def serialize_claim_phase_dates
        return nil if claim_phase_dates.nil?

        {
          'phaseChangeDate' => claim_phase_dates.phase_change_date,
          'phaseType' => claim_phase_dates.phase_type
        }.compact
      end
    end
  end
end
