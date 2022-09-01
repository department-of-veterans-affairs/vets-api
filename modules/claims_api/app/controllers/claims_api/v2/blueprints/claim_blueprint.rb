# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'

module ClaimsApi
  module V2
    module Blueprints
      class ClaimBlueprint < Blueprinter::Base
        field :benefit_claim_type_code
        field :claim_id
        field :claim_type
        field :contention_list
        field :claim_date
        field :close_date
        field :decision_letter_sent
        field :development_letter_sent
        field :documents_needed
        field :end_product_code
        field :errors
        field :jurisdiction
        field :lighthouse_id
        field :max_est_claim_date
        field :min_est_claim_date
        field :status do |claim, _options|
          ClaimsApi::BGSClaimStatusMapper.new(claim[:status]).name
        end
        field :submitter_application_code
        field :submitter_role_code
        field :temp_jurisdiction
        field :tracked_items
        field :supporting_documents
        field '5103_waiver_submitted'.to_sym

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer

        view :list do
          exclude :benefit_claim_type_code
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
