# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class ClaimBlueprint < Blueprinter::Base
        identifier :id

        field :contention_list
        field :date_filed
        field :decision_letter_sent
        field :development_letter_sent
        field :documents_needed
        field :end_product_code
        field :requested_decision
        field :status
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
        field :type

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer

        view :list do
          exclude :contention_list
          exclude :end_product_code
          exclude :supporting_documents

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
