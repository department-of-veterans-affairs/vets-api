# frozen_string_literal: true

require 'vets/model'

module BenefitsClaims
  module Responses
    class ClaimPhaseDates
      include Vets::Model

      attribute :phase_change_date, String
      attribute :current_phase_back, Bool
      attribute :phase_type, String
      attribute :latest_phase_type, String
      attribute :previous_phases, Hash
    end

    class TrackedItem
      include Vets::Model

      attribute :id, Integer
      attribute :display_name, String
      attribute :status, String
      attribute :suspense_date, String
      attribute :type, String
    end

    class SupportingDocument
      include Vets::Model

      attribute :document_id, String
      attribute :document_type_label, String
      attribute :original_file_name, String
      attribute :tracked_item_id, Integer
      attribute :upload_date, String
    end

    class Contention
      include Vets::Model

      attribute :name, String
    end

    class Event
      include Vets::Model

      attribute :date, String
      attribute :type, String
    end

    class Issue
      include Vets::Model

      attribute :active, Bool
      attribute :description, String
      attribute :diagnostic_code, String
      attribute :last_action, String
      attribute :date, String
    end

    class Evidence
      include Vets::Model

      attribute :date, String
      attribute :description, String
      attribute :type, String
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
      attribute :display_title, String
      attribute :claim_type_base, String
      attribute :close_date, String
      attribute :decision_letter_sent, Bool
      attribute :development_letter_sent, Bool
      attribute :documents_needed, Bool
      attribute :end_product_code, String
      attribute :evidence_waiver_submitted5103, Bool
      attribute :lighthouse_id, String
      attribute :status, String
      attribute :supporting_documents, Array
      attribute :evidence_submissions, Array
      attribute :contentions, Array
      attribute :events, Array
      attribute :issues, Array
      attribute :evidence, Array
      attribute :tracked_items, Array
    end
  end
end
