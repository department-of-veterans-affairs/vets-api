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
        field :supporting_documents do |claim, _options|
          auto_established_claim = ClaimsApi::AutoEstablishedClaim.find_by evss_id: claim[:id]
          if auto_established_claim.present?
            auto_established_claim.supporting_documents.map do |document|
              {
                id: document.id,
                md5: if document.file_data['filename'].present?
                       Digest::MD5.hexdigest(document.file_data['filename'])
                     else
                       ''
                     end,
                filename: document.file_data['filename'],
                uploaded_at: document.created_at
              }
            end
          else
            []
          end
        end
        field '5103_waiver_submitted'.to_sym

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer

        view :list do
          exclude :benefit_claim_type_code
          exclude :contention_list
          exclude :jurisdiction
          exclude :max_est_claim_date
          exclude :min_est_claim_date
          exclude :status_type
          exclude :submitter_application_code
          exclude :submitter_role_code
          exclude :supporting_documents
          exclude :temp_jurisdiction

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
