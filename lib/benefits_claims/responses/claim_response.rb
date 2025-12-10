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
    # (vets-website and VA.gov mobile app). All claim providers must return Hash
    # structures matching this format.
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
    end
  end
end
