# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'

module ClaimsApi
  module V2
    module Blueprints
      class ClaimBlueprint < Blueprinter::Base
        field :claim_type_code
        field :claim_date
        field :claim_id
        field :claim_phase_dates
        field :claim_type
        field :close_date
        field :contention_list
        field :decision_letter_sent
        field :development_letter_sent
        field :documents_needed
        field :end_product_code
        field :evidence_waiver_submitted_5103
        field :errors
        field :jurisdiction
        field :lighthouse_id
        field :max_est_claim_date
        field :min_est_claim_date
        field :status do |claim, _options|
          ClaimsApi::BGSClaimStatusMapper.new(claim).name
        end
        field :submitter_application_code
        field :submitter_role_code
        field :supporting_documents
        field :temp_jurisdiction
        field :tracked_items

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer

        view :list do
          exclude :claim_type_code
          exclude :contention_list
          exclude :errors
          exclude :jurisdiction
          exclude :max_est_claim_date
          exclude :min_est_claim_date
          exclude :status_type
          exclude :submitter_application_code
          exclude :submitter_role_code
          exclude :supporting_documents
          exclude :temp_jurisdiction
          exclude :tracked_items

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
