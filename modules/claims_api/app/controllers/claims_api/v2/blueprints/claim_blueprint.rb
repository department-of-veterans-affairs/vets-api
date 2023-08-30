# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class ClaimBlueprint < Blueprinter::Base
        identifier :claim_id, name: :id
        field :type do |_options|
          'claim'
        end
        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer

        view :index do
          field :attributes do |claim, _options|
            {
              base_end_product_code: claim[:base_end_prdct_type_cd],
              claim_date: claim[:claim_date],
              claim_phase_dates: claim[:claim_phase_dates],
              claim_type: claim[:claim_type],
              close_date: claim[:close_date],
              decision_letter_sent: claim[:decision_letter_sent],
              development_letter_sent: claim[:development_letter_sent],
              documents_needed: claim[:documents_needed],
              end_product_code: claim[:end_product_code],
              evidence_waiver_submitted_5103: claim[:evidence_waiver_submitted_5103],
              lighthouse_id: claim[:lighthouse_id],
              status: claim[:status]
            }
          end
          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end

        view :show do
          field :attributes do |claim, _options|
            {
              claim_type_code: claim[:claim_type_code],
              claim_date: claim[:claim_date],
              claim_phase_dates: claim[:claim_phase_dates],
              claim_type: claim[:claim_type],
              close_date: claim[:close_date],
              contentions: claim[:contentions],
              decision_letter_sent: claim[:decision_letter_sent],
              development_letter_sent: claim[:development_letter_sent],
              documents_needed: claim[:documents_needed],
              end_product_code: claim[:end_product_code],
              evidence_waiver_submitted_5103: claim[:evidence_waiver_submitted_5103],
              errors: claim[:errors],
              jurisdiction: claim[:jurisdiction],
              lighthouse_id: claim[:lighthouse_id],
              max_est_claim_date: claim[:max_est_claim_date],
              min_est_claim_date: claim[:min_est_claim_date],
              status: claim[:status],
              submitter_application_code: claim[:submitter_application_code],
              submitter_role_code: claim[:submitter_role_code],
              supporting_documents: claim[:supporting_documents],
              temp_jurisdiction: claim[:temp_jurisdiction],
              tracked_items: claim[:tracked_items]
            }
          end
          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
